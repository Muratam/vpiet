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
    result &= "{i} -> ".fmt() & self.nexts.join(",") & " | {self.startCC} {self.startDP}\n".fmt()
    const maxPlotOrder = 100
    if self.orders.len() > maxPlotOrder:
      let half = maxPlotOrder div 2 - 1
      result &= "  {self.orders[0..half]} ... {self.orders[^half..^1]}".fmt
    else:
      result &= "  {self.orders}".fmt
  var results : seq[string] = @[]
  for i in 0..<self.len():
    results &= self[i].toStr(i)
  return results.join("\n")



proc newGraph(filename:string) : seq[PietProc] =
  var indexTo = filename.newPietMap().newIndexTo()
  result = newSeq[PietProc]()
  # var stack = newStack[int]()
  # Loop_72 のように永遠に(自分の途中に繋がるために)回るものもある
  var graphIndex = 0
  var searched = newSeq[EightDirection[int]](indexTo.blockSize.len())
  proc search(self:var seq[PietProc],startCC:CC,startDP:DP,startIndex:int) : int =
    graphIndex += 1
    result = graphIndex
    var cc = startCC
    var dp = startDP
    var index = startIndex
    var orders = newSeq[OrderAndSize]()
    var rotateTurn = 0
    template terminate(nexts :seq[int]= @[]) = self.add((orders,nexts,startCC,startDP))
    # WARN: 仮想的にstackを作成して道中のシミュレーションをすれば CC / DP が確定する可能性
    while true:
      if searched[index][cc,dp] > 0:
        # orders.add((ErrorOrder,searched[index][cc,dp] - 1))
        terminate(@[searched[index][cc,dp]])
        return
      let next = indexTo.nextEdges[index][cc,dp]
      searched[index][cc,dp] = graphIndex
      case next.order :
      of Switch: # 2方向の可能性に分岐 & 今までの部分をまでをまとめて辺にする
        orders.add((next.order,-1))
        terminate()
        let i = self.len() - 1
        searched[index][cc,dp] = 0
        self[i].nexts &= self.search(CCRight,dp,next.index)
        self[i].nexts &= self.search(CCLeft ,dp,next.index)
        return
      of Pointer: # 4方向の可能性に分岐
        orders.add((next.order,-1))
        terminate()
        searched[index][cc,dp] = 0
        let i = self.len() - 1
        self[i].nexts &= self.search(cc,DPRight,next.index)
        self[i].nexts &= self.search(cc,DPLeft ,next.index)
        self[i].nexts &= self.search(cc,DPUp   ,next.index)
        self[i].nexts &= self.search(cc,DPDown ,next.index)
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
  discard result.search(newCC(),newDP(),0)
  for i in 0..<result.len():
    for n in 0..<result[i].nexts.len():
      result[i].nexts[n] -= 1


proc makeGraph(self:seq[PietProc]) =
  # if true:
  #   echo self
  #   return

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
    # pp.orders
    # pp.nexts
    # pp.start{CC,DP}
    let size = pp.orders.len()
    dot &= fmt"""  a{i} [label = "a{i}\n({size})"];""" & "\n"
    for next in pp.nexts:
      dot &= fmt"""  a{i} -> a{next} [label = ""];""" & "\n"
  dot &= "}"
  echo dot



if isMainModule:
  let params = commandLineParams()
  if params.len() == 0: quit("no params")
  for filename in params:
    let graph = filename.newGraph()
    graph.makeGraph()
