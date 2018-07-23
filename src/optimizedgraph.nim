import common
import pietmap, indexto
import osproc
type ShortEdge = tuple[src,dst:int,order:Order,branch:int,size:int]
  # branch :: dp cc で変更時
proc makeShortEdges(indexTo:IndexTo) : seq[ShortEdge] =
  # block数 x 8 あるのをまず削減
  var nodeIndices = newSeq[EightDirection[int]](indexTo.blockSize.len())
  for i in 0..<nodeIndices.len():nodeIndices[i] = (-1,-1,-1,-1,-1,-1,-1,-1,)
  var maxNodeIndex = -1
  var to = newSeq[ShortEdge]()
  proc search(index:int,dp:DP,cc:CC) :int =
    var (nextIndex,order) = indexTo.nextEdges[index][cc,dp]
    var dp = dp
    var cc = cc
    if order == Wall:
      proc checkWall() =
        for i in 0..<8:
          if i mod 2 == 0: cc.toggle()
          else : dp.toggle(1)
          let next = indexTo.nextEdges[index][cc,dp]
          nextIndex = next.index
          order = next.order
          if order != Wall: return
        order = Terminate
      checkWall()
    # if order == Nop:
    #   search(nextIndex,dp,cc,currentEdgeIndex,branch)
    #   return
    if nodeIndices[index][cc,dp] >= 0:
      return nodeIndices[index][cc,dp]
    maxNodeIndex += 1
    let currentNodeIndex = maxNodeIndex
    nodeIndices[index][cc,dp] = currentNodeIndex

    case order:
    of Switch: # 2方向
      for i in 0..<2:
        let nextNodeIndex = search(nextIndex,dp,cc)
        to &= (currentNodeIndex,nextNodeIndex,order,i,indexTo.blockSize[index])
        cc.toggle()
    of Pointer: # 4方向
      for i in 0..<4:
        let nextNodeIndex = search(nextIndex,dp,cc)
        to &= (currentNodeIndex,nextNodeIndex,order,i,indexTo.blockSize[index])
        dp.toggle(1)
    of Wall: assert false
    of Terminate: return currentNodeIndex
    else:
      let nextNodeIndex = search(nextIndex,dp,cc)
      to &= (currentNodeIndex,nextNodeIndex,order,-1,indexTo.blockSize[index])
    return currentNodeIndex


  discard search(0,newDP(),newCC())
  return to



proc drawGraph(self:seq[ShortEdge]) : string =
  var dot = """digraph pietgraph {
    graph [
      charset = "UTF-8", fontname = "Menlo", style = "filled"
    ];
    node [
      shape = box, fontname = "Menlo", style = "filled",
      fontcolor = "#222222", fillcolor = "#ffffff"
    ];
  """.replace("\n  ","\n")
  for info in self:
    let (src,dst,order,branch,size) = info
    dot &= fmt""" a{src} [label = ""];""" & "\n"
    dot &= fmt""" a{dst} [label = ""];""" & "\n"
    let top = if branch < 0 : "" else: $branch
    let label = "{order}:{top}".fmt()
    dot &= fmt"""  a{src} -> a{dst} [label = "{label}"];""" & "\n"
  dot &= "}"
  return dot



proc showGraph*(self:seq[ShortEdge],
                dotFileName:string="/tmp/piet.dot",
                pngFileName:string="/tmp/piet.png") =
  let dot = self.drawGraph()
  let f = open(dotFileName,fmWrite)
  f.write(dot)
  f.close()
  let command = "dot -Tpng {dotFileName} -o {pngFileName}".fmt()
  let (output,exitCode) = execCmdEx(command)
  if exitCode != 0 :
    echo output
    return
  discard startProcess("/usr/bin/open",args=[pngFileName],options={})


# グラフを作成
proc newGraph*(filename:string) =
  let indexTo = filename.newPietMap().newIndexTo()
  let to = indexTo.makeShortEdges()
  echo to
  to.showGraph()
  # result = indexTo.makeGraph()


if isMainModule:
  let params = commandLineParams()
  if params.len() == 0: quit("no params")
  for filename in params:
    filename.newGraph()