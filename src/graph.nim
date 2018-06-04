import common
import pietmap, indexto

# index <-> index は分かっているので,グラフを作成する
# [0,0,rightL] は 分かっているので,いい感じに解析できるはず

type
  OrderAndSize = tuple[order:Order,size:int]
  PietProc = tuple[
    orders:seq[OrderAndSize],
    nexts:seq[int], # stack-top が 0..
    startCC:CC,
    startDP:DP,
  ]
  # 実行命令列と次に起こりうる遷移Index,

proc `$`*(self:OrderAndSize):string =
  if self.order == Push : return "+{self.size}".fmt
  if self.order == ErrorOrder : return "?{self.size}".fmt
  return $(self.order)
proc `$`*(self:seq[PietProc]):string =
  proc toStr(self:PietProc,i:int):string =
    result = ""
    result &= "{i} -> ".fmt() & self.nexts.join(",") & " | "#{self.startCC} {self.startDP}\n".fmt()
    const maxPlotOrder = 100
    if self.orders.len() > maxPlotOrder:
      let half = maxPlotOrder div 2 - 1
      result &= "{self.orders[0..half]} ... {self.orders[^half..^1]}".fmt
    else:
      result &= "{self.orders}".fmt
  var results : seq[string] = @[]
  for i in 0..<self.len():
    results &= self[i].toStr(i)
  return results.join("\n")

type NotDevidedGraph = tuple[pp:PietProc,devideOrderNum:int,endCC:CC,endDP:DP]
proc `isDevide`(self:NotDevidedGraph) :bool = self.devideOrderNum >= 0
proc newGraph(filename:string) : seq[PietProc] =
  var indexTo = filename.newPietMap().newIndexTo()
  # グラフを作成
  var graphIndex = 0
  var searched = newSeq[EightDirection[tuple[graphIndex,orderNum:int]]](indexTo.blockSize.len())
  # searched[dp,cc].orderNum
  proc search(self:var seq[NotDevidedGraph],startCC:CC,startDP:DP,startIndex:int) : int =
    graphIndex += 1
    result = graphIndex # 予め返り値を保存
    var (cc,dp,index,orders) = (startCC,startDP,startIndex,newSeq[OrderAndSize]())
    template terminate(nexts :seq[int]= @[]) = self.add(((orders,nexts,startCC,startDP),-1,cc,dp))
    # WARN: 仮想的にstackを作成して道中のシミュレーションをすれば CC / DP が確定する可能性
    while true:
      let next = indexTo.nextEdges[index][cc,dp]
      if searched[index][cc,dp].graphIndex > 0:
        let pre = searched[index][cc,dp]
        if pre.orderNum == 0: # 先頭なので直接繋げば分割しなくてよい
          if orders.len() == 0: # 私は空なのでそもそもこの辺はいらなかった
            graphIndex -= 1
            return pre.graphIndex
          terminate(@[pre.graphIndex])
          return
        # orders.add((ErrorOrder,pre.orderNum))
        terminate(@[pre.graphIndex])
        self[^1].devideOrderNum = pre.orderNum
        return
      searched[index][cc,dp] = (graphIndex, orders.len())
      case next.order :
      of Switch: # 2方向の可能性に分岐 & 今までの部分をまでをまとめて辺にする
        orders.add((next.order,-1))
        terminate()
        let i = self.len() - 1
        for _ in 0..<2:
          self[i].pp.nexts &= self.search(cc,dp,next.index)
          cc.toggle()
        return
      of Pointer: # 4方向の可能性に分岐
        orders.add((next.order,-1))
        terminate()
        let i = self.len() - 1
        for _ in 0..<4:
          self[i].pp.nexts &= self.search(cc,dp,next.index)
          dp.toggle(1)
        return
      of Wall:
        proc isTerminateWall() : bool =
          result = true
          for i in 0..<8:
            if i mod 2 == 0: cc.toggle()
            else : dp.toggle(1)
            let next = indexTo.nextEdges[index][cc,dp]
            if next.order != Wall: return false
        if isTerminateWall():
          terminate()
          return
      of Terminate:
        terminate()
        return
      of Nop:
        index = next.index
        continue
      else:
        orders.add((next.order,indexTo.blockSize[index]))
        index = next.index
        continue

  # グラフを分割
  proc devideGraph(self:var seq[NotDevidedGraph]) : seq[PietProc] =
    # 0-indexに合わせる
    for i in 0..<self.len():
      for n in 0..<self[i].pp.nexts.len():
        self[i].pp.nexts[n] -= 1
    # どこで分割したいかを知るために作成
    var to = newSeqWith(self.len(),newSeq[tuple[index:int,orderNum:int]]())
    for i in 0..<self.len():
      if not self[i].isDevide : continue
      let devideGraohIndex = self[i].pp.nexts[0]
      to[devideGraohIndex].add((i,self[i].devideOrderNum))
    # 後ろから見ていくためのソート
    for i in 0..<to.len():
      if to[i].len() == 0 : continue
      to[i].sort((x,y)=> y.orderNum - x.orderNum)
      # echo "{i} <- {to[i]} / {self[i].pp.orders.len()}".fmt()
    # 分割
    var maxIndex = self.len()
    for i in 0..<self.len():
      if to[i].len() == 0 : continue
      let parent = self[i]
      assert(not parent.isDevide())
      var currentDevidePos = -1
      for devider in to[i]:
        var devidePos = devider.orderNum
        var deviderIndex = devider.index
        self[deviderIndex].devideOrderNum = -1
        self[deviderIndex].pp.nexts = @[maxIndex]
        if currentDevidePos == devidePos:
          self[deviderIndex].pp.nexts = @[maxIndex]
          continue
        currentDevidePos = devidePos
        let midCC = self[deviderIndex].endCC
        let midDP = self[deviderIndex].endDP
        let newer = (parent.pp.orders[devidePos..^1],parent.pp.nexts,midCC,midDP)
        self.add((newer,-1,parent.endCC,parent.endDP)) # WARN: CC,DP is wrong(道中のDP,CCをとればいいとはおもう)
        self[i].pp.nexts  = @[maxIndex]
        self[i].pp.orders = self[i].pp.orders[0..devidePos]
        self[i].endCC = midCC
        self[i].endDP = midDP
        maxIndex += 1
    # 長さ 0 の端点書き換え
    for i in 0..<self.len():
      if self[i].pp.orders.len() > 0 : continue
      if self[i].pp.nexts.len() == 0:
        for j in 0..<self.len():
          self[j].pp.nexts = self[j].pp.nexts.filterIt(it != i)
      else:
        let anotherEdge = self[i].pp.nexts[0]
        for j in 0..<self.len():
          self[j].pp.nexts.applyIt(if it == i : anotherEdge else: it)
    # 長さ0のを削除
    var deletedSum = 0
    var deletedSums = newSeq[int](self.len())
    for i in 0..< self.len():
      if self[i].pp.orders.len() == 0 :
        deletedSum += 1
      deletedSums[i] = deletedSum
    result = @[]
    for i in 0..< self.len():
      if self[i].pp.orders.len() == 0 :continue
      self[i].pp.nexts.applyIt(it - deletedSums[it])
      result.add(self[i].pp)

  var notDevidedGraph = newSeq[NotDevidedGraph]()
  discard notDevidedGraph.search(newCC(),newDP(),0)
  result = notDevidedGraph.devideGraph()


proc makeGraph(self:seq[PietProc]) =
  var dot = """digraph pietgraph {
    graph [
      charset = "UTF-8", fontname = "Menlo", style = "filled"
    ];
    node [
      shape = square, fontname = "Menlo", style = "filled",
      fontcolor = "#222222", fillcolor = "#ffffff"
    ];
  """.replace("\n  ","\n")
  for i,pp in self:
    let size = pp.orders.len()
    dot &= fmt"""  a{i} [label = "a{i}\n({size})\n{toMinStr(pp.startCC,pp.startDP)}"];""" & "\n"
    for next in pp.nexts:
      dot &= fmt"""  a{i} -> a{next} [label = ""];""" & "\n"
  dot &= "}"
  echo dot



if isMainModule:
  let params = commandLineParams()
  if params.len() == 0: quit("no params")
  for filename in params:
    let graph = filename.newGraph()
    # echo graph
    graph.makeGraph()
