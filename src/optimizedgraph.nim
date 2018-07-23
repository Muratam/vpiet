import common
import pietmap, indexto
import osproc

type UnionFindTree[T] = ref object
  data: seq[T]
  parent: seq[int]
proc newUnionFindTree(n:int) : UnionFindTree =
  new(result)
  result.parent = newSeqWith(n,-1)
proc root(self:var UnionFindTree,x:int):int =
  if self.parent[x] < 0 : return x
  else:
    self.parent[x] = self.root(self.parent[x])
    return self.parent[x]
proc merge(self:var UnionFindTree,x,y:int):bool=
  var x = self.root(x)
  var y = self.root(y)
  if x == y : return false
  if self.parent[y] < self.parent[x] : (x,y) = (y,x)
  if self.parent[y] == self.parent[x] : self.parent[x] -= 1
  self.parent[y] = x
  return true



type ShortEdge = tuple[src,dst:int,order:Order,branch:int,size:int]
type Edge = tuple[src,dst:int,orderAndSizes:seq[tuple[order:Order,size:int]],branch:int]
# branch :: dp cc で変更時(realNextとかMerge/DevideNopバグがない)
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
    if order == Nop:
      return search(nextIndex,dp,cc)
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
    of Terminate:
      return currentNodeIndex
    else:
      let nextNodeIndex = search(nextIndex,dp,cc)
      to &= (currentNodeIndex,nextNodeIndex,order,-1,indexTo.blockSize[index])
    return currentNodeIndex


  discard search(0,newDP(),newCC())
  return to

proc toEdges(self:seq[ShortEdge]):seq[Edge] =
  result = @[]
  for edge in self:
    let (src,dst,order,branch,size) = edge
    result &= (src,dst,@[(order,size)],branch)

proc getMaxNodeIndex(self:seq[Edge]): int =
  self.mapIt(max(it.src,it.dst)).max() + 1

proc getInEdgesIndexs(self:seq[Edge]) : seq[seq[int]] =
  result = newSeq[seq[int]](self.getMaxNodeIndex())
  for i in 0..<result.len(): result[i] = @[]
  for i,edge in self: result[edge.dst] &= i

proc getOutEdgesIndexs(self:seq[Edge]) : seq[seq[int]] =
  result = newSeq[seq[int]](self.getMaxNodeIndex())
  for i in 0..<result.len(): result[i] = @[]
  for i,edge in self: result[edge.src] &= i

proc deleteNeedlessEdges(self:var seq[Edge]) =
  while true:
    var newGraph = newSeq[Edge]()
    for edge in self:
      if edge.src >= 0: newGraph &= edge
    if newGraph.len() == self.len(): return
    self = newGraph
    let inEdgesIndexs = self.getInEdgesIndexs()
    let outEdgesIndexs = self.getOutEdgesIndexs()
    for i in 0..<self.getMaxNodeIndex():
      if inEdgesIndexs[i].len() != 0 : continue
      if outEdgesIndexs[i].len() == 0 : continue
      if self[outEdgesIndexs[i][0]].src == 0 : continue
      for oe in outEdgesIndexs[i]:
        self[oe].src = -1

proc mergeBridge(self:var seq[Edge]) :bool=
  result = false
  let inEdgesIndexs = self.getInEdgesIndexs()
  let outEdgesIndexs = self.getOutEdgesIndexs()
  for i in 0..<self.getMaxNodeIndex():
    if inEdgesIndexs[i].len() != 1 : continue
    if outEdgesIndexs[i].len() != 1 : continue
    let ie = inEdgesIndexs[i][0]
    let oe = outEdgesIndexs[i][0]
    self[oe].src = self[ie].src
    self[oe].orderAndSizes = self[ie].orderAndSizes & self[oe].orderAndSizes
    self[ie].src = -1
    result = true
  self.deleteNeedlessEdges()

proc filterExitBranch(self:var seq[Edge]) :bool=
  result = false
  let inEdgesIndexs = self.getinEdgesIndexs()
  let outEdgesIndexs = self.getOutEdgesIndexs()
  for i in 0..<self.getMaxNodeIndex():
    if inEdgesIndexs[i].len() != 1 : continue
    if outEdgesIndexs[i].len() < 1 : continue
    let ie = inEdgesIndexs[i][0]
    let orders = outEdgesIndexs[i].mapIt(self[it].orderAndSizes[^1].order)
    let last = self[ie].orderAndSizes[^1]
    if orders.allIt(it == Pointer):
      if last.order == Not:
        for oe in outEdgesIndexs[i]:
          if self[oe].branch >= 2 :
            self[oe].src = -1
            result = true
      elif last.order == Push:
        for oe in outEdgesIndexs[i]:
          if self[oe].branch != last.size mod 4 :
            self[oe].src = -1
            result = true
    elif orders.allIt(it == Switch):
      if last.order == Push:
        for oe in outEdgesIndexs[i]:
          if self[oe].branch != last.size mod 2 :
            self[oe].src = -1
            result = true
  self.deleteNeedlessEdges()


proc drawGraph(self:seq[Edge]) : string =
  var dot = """digraph pietgraph {
    graph [
      charset = "UTF-8", fontname = "Menlo", style = "filled"
    ];
    node [
      shape = box, fontname = "Menlo", style = "filled",
      fontcolor = "#222222", fillcolor = "#ffffff"
    ];
    a0 [label=""]
  """.replace("\n  ","\n")

  for info in self:
    let (src,dst,orderAndSizes,branch) = info
    var label = ""
    for orderAndSize in orderAndSizes:
      let (order,size) = orderAndSize
      if order != Push: label &= "{order}\n".fmt()
      else: label &= "+{size}\n".fmt()
    let nodeLabel = if src == 0 : "START" else: ""
    dot &= " a{src} [label = \"{nodeLabel}\"];\n".fmt()
    let top = if branch < 0 : "" else: ($branch)
    dot &= fmt"""  a{src} -> a{dst} [label = "{top}:{label}"];""" & "\n"
  dot &= "}"
  return dot



proc showGraph*(self:seq[Edge],
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
  var to = indexTo.makeShortEdges().toEdges()
  while true:
    echo "check"
    var updated = false
    updated = updated or to.mergeBridge()
    updated = updated or to.filterExitBranch()
    if not updated: break
  to.showGraph()

  # result = indexTo.makeGraph()


if isMainModule:
  let params = commandLineParams()
  if params.len() == 0: quit("no params")
  for filename in params:
    filename.newGraph()