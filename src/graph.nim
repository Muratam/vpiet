import common
import pietmap, indexto

# index <-> index は分かっているので,グラフを作成する
# [0,0,rightL] は 分かっているので,いい感じに解析できるはず

# proc makeGraph(filename:string) =
#   let core = newPietCore(filename)
#   echo core.filename
#   var dot = """digraph pietgraph {
#     graph [ charset = "UTF-8", fontname = "Menlo", style = "filled" ];
#     node [ shape = square, fontname = "Menlo", style = "filled",
#         fontcolor = "#222222", fillcolor = "#ffffff", ];"""
#   # for i in 0..<maxIndex:
#   #   for _ in 0..<4:
#   #     if rand(1.0) > 0.1 : continue
#   #     let r = rand(maxIndex)
#   #     if r == i : continue
#   #     dot &= fmt"""a{i} [label = "a{i}",fontcolor = "#222222",fillcolor = "#ffffff"];"""
#   #     dot &= fmt"""a{i} -> a{r} [label = "➜"];"""
#   dot &= "}"
#   echo dot
type
  OrderAndSize = tuple[order:Order,size:int]
  PietProc = tuple[
    orders:seq[OrderAndSize],
    next:seq[int], # stack-top が 0..
    startCC:CC,
    startDP:DP,
  ]
  # 実行命令列と次に起こりうる遷移Index,

proc `$`*(self:OrderAndSize):string =
  if self.order != Push : return $(self.order)
  else: return "+{self.size}".fmt

proc newGraph(filename:string) : seq[PietProc] =
  var indexTo = filename.newPietMap().newIndexTo()
  result = newSeq[PietProc]()
  # var stack = newStack[int]()
  # Loop_72 のように永遠に(自分の途中に繋がるために)回るものもある
  var graphMaxIndex = 1
  var searched = newSeq[EightDirection[int]](indexTo.blockSize.len())
  proc search(self:var seq[PietProc],startCC:CC,startDP:DP,startIndex:int,graphIndex:int) =
    var cc = startCC
    var dp = startDP
    var index = startIndex
    var orders = newSeq[OrderAndSize]()
    var rotateTurn = 0
    template terminate(nexts:seq[int] = @[]) = self.add((orders,nexts,startCC,startDP))
    while true:
      if searched[index][cc,dp] > 0:
        terminate()
        return
      searched[index][cc,dp] = graphIndex
      let edges = indexTo.nextEdges[index]
      let edge = edges[cc,dp]
      let nextIndex = indexTo.blockSize[index]
      if edge.order != Wall : rotateTurn = 0
      case edge.order :
      of Switch: # 2方向の可能性に分岐 & 今までの部分をまでをまとめて辺にする
        terminate(@[graphMaxIndex + 1,graphMaxIndex + 2])
        let currentIndex = graphMaxIndex
        graphMaxIndex += 2
        self.search(CCRight,dp,nextIndex,currentIndex + 1)
        self.search(CCLeft ,dp,nextIndex,currentIndex + 2)
        return
      of Pointer: # 4方向の可能性に分岐
        terminate(@[graphMaxIndex + 1,graphMaxIndex + 2,graphMaxIndex + 3,graphMaxIndex + 4])
        let currentIndex = graphMaxIndex
        graphMaxIndex += 4
        self.search(cc,DPRight,nextIndex,currentIndex + 1)
        self.search(cc,DPLeft ,nextIndex,currentIndex + 2)
        self.search(cc,DPUp   ,nextIndex,currentIndex + 3)
        self.search(cc,DPDown ,nextIndex,currentIndex + 4)
        return
      of Wall:
        if rotateTurn < 8:
          if rotateTurn mod 2 == 0: cc.toggle()
          else : dp.toggle(1)
          rotateTurn += 1
          continue
        terminate()
        return
      of Terminate:
        terminate()
        return
      of Nop:
        index = edge.index
        continue
      else:
        orders.add((edge.order,nextIndex))
        index = edge.index
        continue
  result.search(newCC(),newDP(),0,graphMaxIndex)
  echo result





if isMainModule:
  let params = commandLineParams()
  if params.len() == 0: quit("no params")
  for filename in params:
    discard filename.newGraph()
