import ../common
import dpcc, order, orderconf

type
  NWB* = enum None,White,Black
  PietColor* = int16  # no white black

const hueMax* = orderBlock.len()
const lightMax* = orderBlock[0].len()
const WhiteNumber* = hueMax * lightMax
const BlackNumber* = WhiteNumber + 1
const whiteOrder = Nop
const blackOrder = Wall
const maxColorNumber* = BlackNumber

# 211 221 121 122 112 212 => 0 1 2 3 4 5
# 200 220 020 022 002 202 => 6 ...... 11
# 100 110 010 011 001 101 => 12 ..... 17
proc `hue` *(c:PietColor) : range[0..hueMax] =
  # 0(red) ... 5(purple)
  assert c < WhiteNumber and c >= 0,fmt"{c}"
  return c mod hueMax
proc `light` *(c:PietColor) : range[0..lightMax] =
  # 0(light) 1(normal) 2(dark)
  assert c < WhiteNumber and c >= 0,fmt"{c}"
  c div hueMax
proc `nwb` *(c:PietColor) : NWB =
  return case c:
    of WhiteNumber: White
    of BlackNumber: Black
    else: None

proc `hue=`*(c:var PietColor,val:range[0..hueMax]) =
  c = (((val + hueMax) mod hueMax).PietColor +
      (c div hueMax) * hueMax) mod WhiteNumber
proc `light=`*(c:var PietColor,val:range[0..lightMax]) =
  c = (((val + hueMax) mod hueMax).PietColor * hueMax.PietColor +
      (c mod hueMax)) mod WhiteNumber
proc `nwb=`*(c:var PietColor,val:NWB) =
  c = case val:
    of White: WhiteNumber
    of Black: BlackNumber
    of None: c mod WhiteNumber

proc decideOrder*(now,next:PietColor): Order =
  if next.nwb == Black or now.nwb == Black: return blackOrder # 解析のためには黒のこともある
  if next.nwb == White or now.nwb == White: return whiteOrder
  let hueDiff = (hueMax + (next.hue - now.hue) mod hueMax) mod hueMax
  let lightDiff = (lightMax + (next.light - now.light) mod lightMax) mod lightMax
  return orderBlock[hueDiff][lightDiff]

proc decideNext*(now:PietColor,order:Order): PietColor =
  if order == whiteOrder:
    result.nwb = White
    return
  result.nwb = None
  for h,byHue in orderblock:
    for l,o in byHue:
      if o != order: continue
      result.hue = now.hue + h
      result.light = now.light + l
      return
  doAssert false,"cant decide color"