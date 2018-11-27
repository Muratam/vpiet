import common
import pietmap

# index -> { index / size } の接続グラフ
# (元画像のxy情報を完全に排除)

type
  DirectedEdge* = tuple[index:int,order:Order]
  NextDirectedEdges* = EightDirection[DirectedEdge]
  IndexTo* = ref object
    # 実行に最低限必要な情報のみ保存(0番からスタート)
    # この段階で既に画像の情報は不要
    blockSize*: seq[int]
    nextEdges*: seq[NextDirectedEdges]

proc getNextDirectedEdge(self:PietMap,color:PietColor,pos,dxdy:Pos): DirectedEdge =
  block: # non-white
    let (x,y) = pos + dxdy
    if x < 0 or y < 0 or x >= self.width or y >= self.height:
      return (-1,Wall)
    let nextIndex = self.indexMap[x,y]
    let nextColor = self.indexToPietColor[nextIndex]
    if nextColor.nwb != White:
      return (nextIndex,decideOrder(color,nextColor))
  # White WARN: ver.KMC-Piet
  var current = pos
  while true:
    current = current + dxdy
    let (cx,cy) = current
    if cx < 0 or cy < 0 or cx >= self.width or cy >= self.height:
      return (-1,Wall)
    let nextIndex = self.indexMap[cx,cy]
    let nextColor = self.indexToPietColor[nextIndex]
    if nextColor == BlackNumber: return (nextIndex,Wall)
    if nextColor == WhiteNumber: continue
    return (nextIndex,Nop)


proc getDiffEightPos(): EightDirection[Pos] =
  result.upR = PosUp
  result.upL = PosUp
  result.downR = PosDown
  result.downL = PosDown
  result.rightR = PosRight
  result.rightL = PosRight
  result.leftR = PosLeft
  result.leftL = PosLeft

proc newIndexTo*(self:PietMap): IndexTo =
  new(result)
  result.blockSize = self.indexToSize
  result.nextEdges = newSeq[NextDirectedEdges](self.maxIndex)
  let dXdYs = getDiffEightPos()
  for i in 0..< self.maxIndex:
    let endPos = self.indexToEndPos[i]
    let color = self.indexToPietColor[i]
    for ccdp in allCCDP():
      let (cc,dp) = ccdp
      result.nextEdges[i][cc,dp] = self.getNextDirectedEdge(color,endPos[cc,dp],dXdYs[cc,dp])
