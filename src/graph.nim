import common
import pietmap, indexto

# index <-> index は分かっているので,グラフを作成する
# [0,0,rightL] は 分かっているので,いい感じに解析できるはず

type
  OrderWithInfo = tuple[order:Order,size:int,dp:DP,cc:CC]
  PietProc = tuple[
    orders:seq[OrderWithInfo],
    nexts:seq[int], # stack-top が 0..
    startCC:CC,
    startDP:DP,
  ]
  # 実行命令列と次に起こりうる遷移Index,

proc `$`*(self:OrderWithInfo):string =
  if self.order == Push : return "+{self.size}".fmt
  if self.order == Pointer : return "DP".fmt
  if self.order == Switch : return "CC".fmt
  if self.order == Wall : return "#".fmt
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

proc newGraph(filename:string) : seq[PietProc] =
  # グラフを作成
  # Nopの分がバグの原因？(違うと思う)
  # optimizeNextする前は全ての cc dp 関係が正しくあるはず
  type NotDevidedGraph = tuple[pp:PietProc,devideOrderNum:int,endCC:CC,endDP:DP]
  proc `isDevider`(self:NotDevidedGraph) :bool = self.devideOrderNum >= 0
  proc makeNotDevidedGraph(indexTo:IndexTo): seq[NotDevidedGraph] =
    type SearchTrace = tuple[graphIndex,orderNum:int]
    var searched = newSeq[EightDirection[SearchTrace]](indexTo.blockSize.len())
    var graphIndex = 0
    proc search(self:var seq[NotDevidedGraph],startCC:CC,startDP:DP,startIndex:int) : int =
      graphIndex += 1
      result = graphIndex # 予め返り値を保存
      var (cc,dp,index,orders) = (startCC,startDP,startIndex,newSeq[OrderWithInfo]())
      template terminate(nexts :seq[int]= @[]) = self.add(((orders,nexts,startCC,startDP),-1,cc,dp))
      while true:
        if searched[index][cc,dp].graphIndex > 0:
          let pre = searched[index][cc,dp]
          if pre.orderNum == 0: # 先頭なので直接繋げば分割しなくてよい
            # selfを参照する際は1-indexedではない！
            assert cc == self[pre.graphIndex - 1].pp.startcc
            assert dp == self[pre.graphIndex - 1].pp.startdp
            if orders.len() == 0: # 私は空なのでそもそもこの辺はいらなかった
              graphIndex -= 1
              return pre.graphIndex
            terminate(@[pre.graphIndex])
            return
          terminate(@[pre.graphIndex])
          self[^1].devideOrderNum = pre.orderNum
          return
        searched[index][cc,dp] = (graphIndex, orders.len())
        let next = indexTo.nextEdges[index][cc,dp]
        template pushOrder(order:Order=next.order) = orders.add((order,indexTo.blockSize[index],dp,cc))
        case next.order :
        of Switch: # 2方向の可能性に分岐 & 今までの部分をまでをまとめて辺にする
          pushOrder()
          terminate()
          let current = self.len() - 1
          for _ in 0..<2:
            self[current].pp.nexts &= self.search(cc,dp,next.index)
            cc.toggle()
          return
        of Pointer: # 4方向の可能性に分岐
          pushOrder()
          terminate()
          let current = self.len() - 1
          for _ in 0..<4:
            self[current].pp.nexts &= self.search(cc,dp,next.index)
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
            pushOrder(Terminate)
            terminate()
            return
          pushOrder()
        of Terminate:
          pushOrder()
          terminate()
          return
        of Nop:
          index = next.index
        else:
          pushOrder()
          index = next.index
    # 0-indexに合わせる
    proc to0Indexed(self:var seq[NotDevidedGraph]) =
      for i in 0..<self.len():
        for n in 0..<self[i].pp.nexts.len():
          self[i].pp.nexts[n] -= 1
    # impl
    result = newSeq[NotDevidedGraph]()
    discard result.search(newCC(),newDP(),0)
    result.to0Indexed()

  # グラフを分割 & 圧縮
  proc devideGraph(self:var seq[NotDevidedGraph]) : seq[PietProc] =
    # どこで分割したいかを知るために作成
    var to = newSeqWith(self.len(),newSeq[tuple[index:int,orderNum:int]]())
    for i in 0..<self.len():
      if not self[i].isDevider : continue
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
      assert(not parent.isDevider)
      var currentDevidePos = -1
      for devider in to[i]:
        var devidePos = devider.orderNum
        var deviderIndex = devider.index
        assert self[deviderIndex].pp.nexts.len == 1
        self[deviderIndex].devideOrderNum = -1
        self[deviderIndex].pp.nexts = @[maxIndex]
        if currentDevidePos == devidePos:
          continue
        currentDevidePos = devidePos
        let midCC = self[deviderIndex].endCC
        let midDP = self[deviderIndex].endDP
        let newer = (parent.pp.orders[devidePos..^1],parent.pp.nexts,midCC,midDP)
        self.add((newer,-1,parent.endCC,parent.endDP))
        self[i].pp.nexts  = @[maxIndex]
        self[i].pp.orders = self[i].pp.orders[0..devidePos-1]
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
    return self.mapIt(it.pp)
  # 行かないノードを探して削除
  proc optimizeNext(self:var seq[PietProc]) =
    proc execToDetectNeedLessNode(self:var seq[PietProc]) : bool =
      result = false
      for i in 0..<self.len():
        let pp = self[i]
        if pp.nexts.len() <= 1: continue
        var nextDPCCIndex = 0
        proc testPiet(): bool =
          var dp = pp.startDP
          var cc = pp.startCC
          var stack = newStack[int]()
          proc step(info:OrderWithInfo) : bool =
            result = true
            cc = info.cc
            dp = info.dp
            template binaryIt(op) =
              if stack.len() < 2 : return false
              let a {.inject.}= stack.pop()
              let b {.inject.}= stack.pop()
              op
            template unaryIt(op) =
              if stack.len() < 1 : return false
              let it {.inject.} = stack.pop()
              op
            case info.order
            of Add: binaryIt(stack.push(b + a))
            of Sub: binaryIt(stack.push(b - a))
            of Mul: binaryIt(stack.push(b * a))
            of Div: binaryIt(stack.push(b div a))
            of Mod: binaryIt(stack.push(b mod a))
            of Greater: binaryIt(stack.push(if b > a : 1 else: 0))
            of Push: stack.push(info.size)
            of Pop: unaryIt((discard))
            of Not: unaryIt(stack.push(if it > 0 : 0 else: 1))
            of Pointer: unaryIt((nextDPCCIndex = ((it mod 4) + 4 mod 4)))
            of Switch:  unaryIt((nextDPCCIndex = ((it mod 2) + 2 mod 2)))
            of InC: return false #
            of InN: return false
            of OutN: discard
            of OutC: discard
            of Dup: unaryIt((stack.push(it);stack.push(it)))
            of Roll:
              if stack.len() < 3 : return false
              let a = stack.pop() # a 回転
              var b = stack.pop() # 深さ b まで
              if b > stack.len(): return false
              var roll = newSeq[int]()
              for i in 0..<b: roll.add(stack.pop())
              for i in 0..<b: stack.push(roll[(i + a) mod b])
            of Wall:discard
            else:discard
          for order in pp.orders:
            if not step(order): return false
          return true
        if not testPiet(): continue
        let newOne = @[self[i].nexts[nextDPCCIndex]]
        # ただ一通りに決まる時がある(最適化のせいでそうでないときもあるかも)
        if newOne.len == self[i].nexts.len(): continue
        result = true
        self[i].nexts = newOne

    proc deleteNeedLessNode(self:var seq[PietProc]) : bool =
      proc deleteImpl(self:seq[PietProc]): seq[PietProc] =
        var isUsed = newSeq[bool](self.len())
        for pp in self:
          for next in pp.nexts:
            isUsed[next] = true
        var deletedSum = 0
        var deletedSums = newSeq[int](self.len())
        for i in 0..< self.len():
          if not isUsed[i]: deletedSum += 1
          deletedSums[i] = deletedSum
        result = @[]
        for i in 0..< self.len():
          if not isUsed[i] :continue
          result.add(self[i])
          result[^1].nexts.applyIt(it - deletedSums[it])
      result = false
      while true:
        let newOne = self.deleteImpl()
        if newOne.len == self.len: return
        self = newOne
        result = true
    proc deleteWallNode(self:var seq[PietProc]) =
      # nexts: stackTop が {None,0} 1 2 3 ... の順と仮定してよい
      for i in 0..<self.len():
        if self[i].orders.anyIt(it.order != Wall): continue
        if self[i].nexts.len != 1 : continue
        # i へのノードを先っぽに付け替え
        for j in 0..<self.len():
          for n in 0..<self[j].nexts.len():
            if self[j].nexts[n] != i: continue
            self[j].nexts[n] = self[i].nexts[0]
      for i in 0..<self.len():
        if self[i].orders.len == 0 : continue
        self[i].orders = self[i].orders.filterIt(it.order != Wall)



    # 誰からも参照されない 0 番以外のものを更新されなくなるまで消す
    # 更新されなくなるまで繰り返す
    while true:
      # echo self.len()
      discard self.execToDetectNeedLessNode()
      self.deleteWallNode()
      if not self.deleteNeedLessNode():break



  let indexTo = filename.newPietMap().newIndexTo()
  var graph = indexTo.makeNotDevidedGraph()
  # return graph.mapIt(it.pp)
  result = graph.devideGraph()
  result.optimizeNext()

proc makeGraph(self:seq[PietProc]) =
  var dot = """digraph pietgraph {
    graph [
      charset = "UTF-8", fontname = "Menlo", style = "filled"
    ];
    node [
      shape = box, fontname = "Menlo", style = "filled",
      fontcolor = "#222222", fillcolor = "#ffffff"
    ];
  """.replace("\n  ","\n")
  for i,pp in self:
    let order =
      if pp.orders.len() == 1: $(pp.orders[0])
      elif pp.orders.len() == 0: ""
      else: "{pp.orders[0]}..{pp.orders[^1]}".fmt()
      # else : "{pp.orders}".fmt()
    let ccdp = "{toMinStr(pp.startCC,pp.startDP)}".fmt
    var content = "({pp.orders.len()}) {ccdp}\n{order}".fmt
    if i == 0: content = "START\n" & content
    dot &= fmt"""  a{i} [label = "{content}"];""" & "\n"
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
