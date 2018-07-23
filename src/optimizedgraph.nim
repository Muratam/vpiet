import common
import pietmap, indexto
import osproc

type ShortEdge = tuple[src,dst:int,order:Order,branch:int,size:int]
type Edge = tuple[src,dst:int,orderAndSizes:seq[tuple[order:Order,size:int]],branch:int]

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
  result = newSeq[seq[int]](self.getMaxNodeIndex())
  for i in 0..<result.len(): result[i] = @[]
  for i,edge in self: result[edge.dst] &= i

proc getOutEdgesIndexs(self:seq[Edge]) : seq[seq[int]] =
  result = newSeq[seq[int]](self.getMaxNodeIndex())
  for i in 0..<result.len(): result[i] = @[]
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
  let inEdgesIndexs = self.getInEdgesIndexs()
  let outEdgesIndexs = self.getOutEdgesIndexs()
  for i in 0..<self.getMaxNodeIndex():
    if inEdgesIndexs[i].len() != 1 : continue
    if outEdgesIndexs[i].len() != 1 : continue
    let ie = inEdgesIndexs[i][0]
    let oe = outEdgesIndexs[i][0]
    if  self[oe].src == 0 : continue
    self[oe].src = self[ie].src
    self[oe].orderAndSizes = self[ie].orderAndSizes & self[oe].orderAndSizes
    self[oe].branch = self[ie].branch
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
    let orders = outEdgesIndexs[i].mapIt(self[it].orderAndSizes[0].order)
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



#[
proc deleteSameNode(self:var seq[Edge]):bool =
  result = false
  let inEdgesIndexs = self.getinEdgesIndexs()
  let outEdgesIndexs = self.getOutEdgesIndexs()
  let maxNodeIndex = self.getMaxNodeIndex()
  for i in 0..<maxNodeIndex:
    if inEdgesIndexs[i].len() < 1 : continue
    if outEdgesIndexs[i].len() < 1 : continue
    for j in (i+1)..<maxNodeIndex:
      if inEdgesIndexs[j].len() < 1 : continue
      if outEdgesIndexs[j].len() < 1 : continue
      if inEdgesIndexs[j].len() != inEdgesIndexs[i].len():continue
      if outEdgesIndexs[j].len() != outEdgesIndexs[i].len():continue
      var ok = true
      for ie in inEdgesIndexs[i] :
        ok = ok and inEdgesIndexs[j].anyIt(self[it].isSame(self[ie]))
      for oe in outEdgesIndexs[i] :
        ok = ok and outEdgesIndexs[j].anyIt(self[it].isSame(self[oe]))
      ok = ok and (
        outEdgesIndexs[j].anyIt(self[it].orderAndSizes.len() >= 5) or
        inEdgesIndexs[j].anyIt(self[it].orderAndSizes.len() >= 5)
      )
      if ok:
        echo "############"
        echo inEdgesIndexs[j].mapIt(self[it])
        echo inEdgesIndexs[i].mapIt(self[it])
        echo outEdgesIndexs[j].mapIt(self[it])
        echo outEdgesIndexs[i].mapIt(self[it])
        let src = self[outEdgesIndexs[i][0]].src
        let dst = self[inEdgesIndexs[i][0]].dst
        for ie in inEdgesIndexs[j] : self[ie].dst = dst
        for oe in outEdgesIndexs[j] : self[oe].src = src
        result = true
        self.deleteNeedlessEdges()
        return true

]#



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
    for i,orderAndSize in orderAndSizes:
      let (order,size) = orderAndSize
      if order != Push: label &= "{order} ".fmt()
      else: label &= "+{size} ".fmt()
      if i mod 6 == 0 : label &= "\n"
    let nodeLabel = if src == 0 : "START" else: ""
    dot &= " a{src} [label = \"{nodeLabel}\"];\n".fmt()
    let top = if branch < 0 : "" else: ($branch) & ":"
    let dstNode = if orderAndSizes[^1].order == Terminate : "END" else: "a{dst}".fmt()
    dot &= fmt"""  a{src} -> {dstNode} [label = "{top}{label}"];""" & "\n"
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
    # updated = updated or to.deleteSameNode()
    if not updated: break
  to.showGraph()

  # result = indexTo.makeGraph()


if isMainModule:
  let params = commandLineParams()
  if params.len() == 0: quit("no params")
  for filename in params:
    filename.newGraph()