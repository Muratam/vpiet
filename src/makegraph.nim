import common
import pietmap, indexto
import osproc

type
  ShortEdge* = tuple[src,dst:int,order:Order,branch:int,size:int]

  OrderAndSize* = tuple[order:Order,size:int]
  Edge* = tuple[src,dst:int,orderAndSizes:seq[OrderAndSize],branch:int]

proc `$`(self:Edge):string =
  "[{self.src}->{self.dst}:br={self.branch}:or={self.orderAndSizes.len()}]".fmt()


proc isSame(x,y:Edge,checkBranch:bool=true):bool =
  if x.orderAndSizes.len() != y.orderAndSizes.len(): return false
  if checkBranch and x.branch != y.branch : return false
  for i in 0..<x.orderAndSizes.len():
    let xs = x.orderAndSizes[i]
    let ys = x.orderAndSizes[i]
    if xs.order != ys.order : return false
    if xs.order == Push :
      if xs.size != ys.size : return false
  return true

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
      maxNodeIndex += 1
      to &= (currentNodeIndex,maxNodeIndex,order,-1,indexTo.blockSize[index])
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
  result = newSeqWith(self.getMaxNodeIndex(),newSeq[int]())
  for i,edge in self: result[edge.dst] &= i

proc getOutEdgesIndexs*(self:seq[Edge]) : seq[seq[int]] =
  result = newSeqWith(self.getMaxNodeIndex(),newSeq[int]())
  for i,edge in self: result[edge.src] &= i

proc deleteNeedlessEdges(self:var seq[Edge]) =
  proc clean(self:var seq[Edge]) : bool =
    var newGraph = newSeq[Edge]()
    for edge in self:
      if edge.src >= 0: newGraph &= edge
    if self.len() == newGraph.len() : return false
    self = newGraph
    return true
  while true:
    discard self.clean()
    # START 以外の入力のないものの削除
    block:
      let inEdgesIndexs = self.getInEdgesIndexs()
      let outEdgesIndexs = self.getOutEdgesIndexs()
      for i in 0..<self.getMaxNodeIndex():
        if inEdgesIndexs[i].len() != 0 : continue
        if outEdgesIndexs[i].len() == 0 : continue
        if self[outEdgesIndexs[i][0]].src == 0 : continue
        for oe in outEdgesIndexs[i]: self[oe].src = -1
      discard self.clean()
    # branchだけが異なるエッジの削除
    block:
      let outEdgesIndexs = self.getOutEdgesIndexs()
      for i in 0..<self.getMaxNodeIndex():
        if outEdgesIndexs[i].len() <= 1 : continue
        let dsts = outEdgesIndexs[i].mapIt(self[it].dst)
        if dsts.min() != dsts.max(): continue
        var ok = true
        for a in 0..<outEdgesIndexs[i].len():
          for b in (a+1)..<outEdgesIndexs[i].len():
            if not isSame(self[outEdgesIndexs[i][a]],self[outEdgesIndexs[i][b]],false):
              ok = false
        if not ok : continue
        self[outEdgesIndexs[i][0]].branch = -1
        for a in 1..<outEdgesIndexs[i].len():
          self[outEdgesIndexs[i][a]].src = -1
      discard self.clean()
    # 完全に同じエッジの削除
    block:
      for i in 0..<self.len():
        for j in (i+1)..<self.len():
          if not self[i].isSame(self[j]): continue
          if self[i].src != self[j].src : continue
          if (self[i].dst != self[j].dst) and (self[i].orderAndSizes[^1].order != Terminate) : continue
          self[j].src = -1
    if not self.clean() : return


proc mergeBridge(self:var seq[Edge]) :bool=
  result = false
  proc merge(self:var seq[Edge]):bool =
    let inEdgesIndexs = self.getInEdgesIndexs()
    let outEdgesIndexs = self.getOutEdgesIndexs()
    for i in 0..<self.getMaxNodeIndex():
      if inEdgesIndexs[i].len() != 1 : continue
      if outEdgesIndexs[i].len() != 1 : continue
      let ie = inEdgesIndexs[i][0]
      let oe = outEdgesIndexs[i][0]
      if  self[oe].src == 0 : continue
      # if  self[ie].src == 0 : continue
      self[oe].src = self[ie].src
      self[oe].orderAndSizes = self[ie].orderAndSizes & self[oe].orderAndSizes
      self[oe].branch = self[ie].branch
      self[ie].src = -1
      self.deleteNeedlessEdges()
      return true
  while self.merge(): result = true

proc filterExitBranch(self:var seq[Edge]) : bool =
  result = false
  let outEdgesIndexs = self.getOutEdgesIndexs()
  # 到達可能なエッジにマークを付け,マークのつかなかったエッジを削除
  var edgeMarkers = newSeq[bool](self.getMaxNodeIndex())
  proc mark(self:var seq[Edge],index:int) =
    let dst = self[index].dst
    let last = self[index].orderAndSizes[^1]
    for oe in outEdgesIndexs[dst]:
      if edgeMarkers[oe] : continue
      let branch = self[oe].branch
      let order = self[oe].orderAndSizes[0].order
      var allowBranch = @[0,1,2,3]
      if order == Pointer:
        if last.order == Not: allowBranch = @[0,1]
        elif last.order == Push: allowBranch = @[last.size mod 4]
      elif order == Switch:
        if last.order == Push: allowBranch = @[last.size mod 2]
      if branch != -1 and branch notin allowBranch : continue
      edgeMarkers[oe] = true
      self.mark(oe)
  let startIndex = toSeq(0..<self.len()).filterIt(self[it].src == 0)[0]
  edgeMarkers[startIndex] = true
  self.mark(startIndex)
  for i in 0..<self.len():
    if edgeMarkers[i]: continue
    self[i].src = -1
    result = true
  self.deleteNeedlessEdges()


# グラフを作成
proc newGraph*(filename:string) :seq[Edge]=
  let indexTo = filename.newPietMap().newIndexTo()
  var to = indexTo.makeShortEdges().toEdges()
  while true:
    # echo "check"
    var updated = false
    updated = updated or to.mergeBridge()
    updated = updated or to.filterExitBranch()
    if not updated: break
  return to
if isMainModule:
  let params = commandLineParams()
  if params.len() == 0: quit("no params")
  for filename in params:
    discard filename.newGraph()