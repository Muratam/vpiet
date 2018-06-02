import sequtils,strutils,algorithm,math,future,macros,strformat
import nimPNG
import os
import util
import times

type
  RGBA* = tuple[r,g,b,a:uint8]
  NWB* = enum None,White,Black
  PietColor* = int16  # no white black
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

# PietColor
# 211 221 121 122 112 212 => 0 1 2 3 4 5
# 200 220 020 022 002 202 => 6 ...... 11
# 100 110 010 011 001 101 => 12 ..... 17
proc `hue` *(c:PietColor) : range[0..6] =
  assert c < 18 and c >= 0,fmt"{c}"
  return c mod 6 # 0(red) ... 5(purple)
proc `light` *(c:PietColor) : range[0..3] =
  assert c < 18 and c >= 0,fmt"{c}"
  c div 6 # 0(light) 1(normal) 2(dark)
const WhiteNumber* = 18
const BlackNumber* = 19
proc `nwb` *(c:PietColor) : NWB =
  return case c:
    of WhiteNumber: White
    of BlackNumber: Black
    else: None
proc toRGB*(c:PietColor):tuple[r,g,b:uint8] =
  const x00 = 0.uint8
  const xc0 = 192.uint8
  const xff = 255.uint8
  case c:
    of WhiteNumber: return (xff,xff,xff)
    of BlackNumber: return (x00,x00,x00)
    else:
      let l = if c.light == 0 : xc0 else: x00
      let h = if c.light == 2 : xc0 else: xff
      return case c.hue:
        of 0: (h,l,l)
        of 1: (h,h,l)
        of 2: (l,h,l)
        of 3: (l,h,h)
        of 4: (l,l,h)
        of 5: (h,l,h)
        else: (h,h,h)


#[
  proc `hue=`*(c:var PietColor,val:range[0..6]) = c = val + (c div 6) * 6
  proc `light=`*(c:var PietColor,val:range[0..3]) = c = val * 6.PietColor + (c mod 6)
  proc `nwb=`*(c:var PietColor,val:NWB) =
    c = case val:
      of White: WhiteNumber
      of Black: BlackNumber
      of None: c mod 18
  proc `$`*(self:PietColor): string =
    return case self.nwb:
      of None: "{self.hue}{('A'.int + self.light).char}".fmt
      of White: ".."
      of Black: "  "
]#

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

# imgをPietで扱いやすいように直接離散化
proc toColorMap*(img:PNGResult): Matrix[PietColor] =
  result = newMatrix[PietColor](img.width,img.height)
  let n = img.data.len div (img.width * img.height)
  for y in 0..<img.height:
    for x in 0..<img.width:
      let start = n * (x + y * img.width)
      let
        r = img.data[start]
        g = img.data[start+1]
        b = img.data[start+2]
      if r == g and g == b :
        result[x,y] = if r == '\xff' : WhiteNumber else: BlackNumber
      else:
        let isLight :int16 = if r >= '\xc0' and g >= '\xc0' and b >= '\xc0': -6 else: 0
        let isDark :int16 = if r <= '\xc0' and g <= '\xc0' and b <= '\xc0': 6 else : 0
        let hue :int16 =
          if r > g and g == b : 0
          elif r == g and g > b : 1
          elif r < g and g > b : 2
          elif r < g and g == b : 3
          elif r == g and g < b : 4
          else : 5
        result[x,y] = (6 + isLight + isDark + hue)


# 解析し,indexをつける(高速 and StackOverflow対策済み)
proc analyzeColorMap(self:var PietMap,colorMap: Matrix[PietColor]) =
  self.width = colorMap.width
  self.height = colorMap.height
  self.pietColorMap = colorMap
  var indexMap = newMatrix[int](self.width,self.height)
  var stack = newStack[Pos](( self.width + self.height ) * 2)
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
    while not stack.isEmpty():
      let (x,y) = stack.pop()
      if indexMap[x,y] == index : continue # 探索済みの可能性はある
      indexMap[x,y] = index
      blockSize += 1
      updateEndPos(x,y)
      for dxdy in [(-1, 0), (1, 0), (0, 1), (0, -1)]:
        let (dx,dy) = dxdy
        let (x2,y2) = (x+dx,y+dy)
        if x2 < 0 or y2 < 0 or x2 >= self.width or y2 >= self.height : continue
        if indexMap[x2,y2] > 0 or self.pietColorMap[x2,y2] != color: continue
        stack.push((x2.int32,y2.int32))

  # 1-origin (0 is not-defined) # 0.4s
  self.indexToPietColor = @[]
  self.indexToEndPos = @[]
  self.indexToSize = @[]
  for y in 0 ..< self.height:
    for x in 0 ..< self.width:
      if indexMap[x,y] > 0 : continue
      blockSize = 0
      index += 1
      let here = (x.int32,y.int32)
      stack.push(here)
      endPos = (here,here,here,here,here,here,here,here)
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
  let image = loadPNG32(filename)
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