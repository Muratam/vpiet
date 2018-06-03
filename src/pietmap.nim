import sequtils,strutils,algorithm,math,future,macros,strformat
import nimPNG
import os
import util
import times
import pietcolor

# PNG ファイルから PietColor ブロック毎に色とindexを付ける

type
  RGBA* = tuple[r,g,b,a:uint8]
  EndPos* = EightDirection[Pos]
  PietMap* = ref object of RootObj
    filename*:string
    width*,height*:int
    pietColorMap*: Matrix[PietColor]
    indexMap*: Matrix[int] # 1 .. N まで各ブロックに一意のインデックスを貼る
    maxIndex*:int
    indexToPietColor*:seq[PietColor] # index毎の色を保存
    indexToEndPos*:seq[EndPos] # index毎の端の地点のxyを保存
    indexToSize*:seq[int] # index毎のサイズを保存


proc getRGBA*(img:PNGResult,x,y:int): RGBA =
  let n = img.data.len div (img.width * img.height)
  result.r = img.data[n * (x + y * img.width) + 0].uint8
  result.g = img.data[n * (x + y * img.width) + 1].uint8
  result.b = img.data[n * (x + y * img.width) + 2].uint8
  if n <= 3 : return
  result.a = img.data[n * (x + y * img.width) + 3].uint8

# RGBAの行列に変換
proc getRGBAMatrix*(img:PNGResult):Matrix[RGBA] =
  result = newMatrix[RGBA](img.width , img.height)
  let n = img.data.len div (img.width * img.height)
  for y in 0..<img.height:
    for x in 0..<img.width:
      result[x,y].r = img.data[n * (x + y * img.width) + 0].uint8
      result[x,y].g = img.data[n * (x + y * img.width) + 1].uint8
      result[x,y].b = img.data[n * (x + y * img.width) + 2].uint8
  if n <= 3 : return
  for y in 0..<img.height:
    for x in 0..<img.width:
      result[x,y].a = img.data[n * (x + y * img.width) + 3].uint8

proc getPietColor(img:PNGResult,start:int): PietColor =
  let
    r = img.data[start]
    g = img.data[start+1]
    b = img.data[start+2]
  if r == g and g == b :
    if r == '\xff': return WhiteNumber
    return BlackNumber
  let hue :PietColor =
    if r > g and g == b : 0
    elif r == g and g > b : 1
    elif r < g and g > b : 2
    elif r < g and g == b : 3
    elif r == g and g < b : 4
    else : 5
  # isDark
  if r <= '\xc0' and g <= '\xc0' and b <= '\xc0': return hue + 12
  # isLight
  if r >= '\xc0' and g >= '\xc0' and b >= '\xc0': return hue
  # normal
  return 6 + hue


# imgをPietで扱いやすいように直接離散化
proc toColorMap*(img:PNGResult): Matrix[PietColor] =
  result = newMatrix[PietColor](img.width,img.height)
  let n = img.data.len div (img.width * img.height)
  for y in 0..<img.height:
    for x in 0..<img.width:
      let start = n * (x + y * img.width)
      result[x,y] = img.getPietColor(start)



proc analyzeColorMap(self:var PietMap,colorMap: Matrix[PietColor]) =
  self.width = colorMap.width
  self.height = colorMap.height
  self.pietColorMap = colorMap
  var indexMap = newMatrix[int](self.width,self.height)
  var stack = newStack[Pos]( 64.max(self.width * self.height div 4))
  var index = 0
  var endPos : EndPos
  var blockSize = 0

  proc updateEndPos(x,y:int32) =
    if y < endPos.upR.y : endPos.upR = (x,y)
    elif y == endPos.upR.y and x > endPos.upR.x : endPos.upR = (x,y)
    if y < endPos.upL.y : endPos.upL = (x,y)
    elif y == endPos.upL.y and x < endPos.upL.x : endPos.upL = (x,y)
    if y > endPos.downR.y : endPos.downR = (x,y)
    elif y == endPos.downR.y and x < endPos.downR.x : endPos.downR = (x,y)
    if y > endPos.downL.y : endPos.downL = (x,y)
    elif y == endPos.downL.y and x > endPos.downL.x : endPos.downL = (x,y)
    if x < endPos.leftR.x : endPos.leftR = (x,y)
    elif x == endPos.leftR.x and y < endPos.leftR.y : endPos.leftR = (x,y)
    if x < endPos.leftL.x : endPos.leftL = (x,y)
    elif x == endPos.leftL.x and y > endPos.leftL.y : endPos.leftL = (x,y)
    if x > endPos.rightR.x : endPos.rightR = (x,y)
    elif x == endPos.rightR.x and y > endPos.rightR.y : endPos.rightR = (x,y)
    if x > endPos.rightL.x : endPos.rightL = (x,y)
    elif x == endPos.rightL.x and y < endPos.rightL.y : endPos.rightL = (x,y)
  proc find(self:var PietMap,color:PietColor) =
    template searchNext(x2,y2:int32,op:untyped): untyped =
      block:
        let x {.inject.} = x2
        let y {.inject.} = y2
        if op and indexMap[x,y] == 0 and self.pietColorMap[x,y] == color:
          indexMap[x,y] = index
          stack.push((x,y))
    while not stack.isEmpty():
      let (x,y) = stack.pop()
      blockSize += 1
      updateEndPos(x,y) # 0.03
      searchNext(x-1,y  ,x >= 0) # 0.02 * 4
      searchNext(x+1,y  ,x < self.width)
      searchNext(x  ,y-1,y >= 0)
      searchNext(x  ,y+1,y < self.height)
  # 1-origin (0 is not-defined)
  self.indexToPietColor = @[]
  self.indexToEndPos = @[]
  self.indexToSize = @[]

  for y in 0 ..< self.height: # 0.4s
    for x in 0 ..< self.width:
      if indexMap[x,y] > 0 : continue
      blockSize = 0
      index += 1
      let here = (x.int32,y.int32)
      stack.push(here)
      endPos = (here,here,here,here,here,here,here,here)
      indexMap[x,y] = index
      self.find(self.pietColorMap[x,y])
      self.indexToPietColor.add(self.pietColorMap[x,y])
      self.indexToEndPos.add(endPos)
      self.indexToSize.add(blockSize)
  # 0-origin
  for y in 0 ..< self.height:
    for x in 0 ..< self.width:
      indexMap[x,y] -= 1
  self.indexMap = indexMap
  self.maxIndex = index


proc newPietMap*(filename:string): PietMap =
  new(result)
  result.filename = filename
  let image = loadPNG32(filename) # 0.18s
  let colorMap = image.toColorMap() # 0.08s
  result.analyzeColorMap(colorMap) # 0.40s

proc newPietMap*(colorMap:Matrix[PietColor],tempName :string = "out.png"): PietMap =
  new(result)
  result.filename = tempName
  result.analyzeColorMap(colorMap) # 0.40s


if isMainModule:
  # Piet地図の解析を行い,掛かった時間を表示
  let params = os.commandLineParams()
  if params.len() == 0: quit("no params")
  for filename in params:
    let pietMap = newPietMap(filename)
    echo "# {filename}\ntime : {cpuTime()} s\nsize : {pietMap.maxIndex}".fmt