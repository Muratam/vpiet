import common
import nimPNG


type
  NWB* = enum None,White,Black
  PietColor* = int16  # no white black
  # 211 221 121 122 112 212 => 0 1 2 3 4 5
  # 200 220 020 022 002 202 => 6 ...... 11
  # 100 110 010 011 001 101 => 12 ..... 17

const WhiteNumber* = 18
const BlackNumber* = 19
proc `hue` *(c:PietColor) : range[0..6] =
  assert c < 18 and c >= 0,fmt"{c}"
  return c mod 6 # 0(red) ... 5(purple)
proc `light` *(c:PietColor) : range[0..3] =
  assert c < 18 and c >= 0,fmt"{c}"
  c div 6 # 0(light) 1(normal) 2(dark)
proc `hue=`*(c:var PietColor,val:range[0..6]) =
  c = (((val + 6) mod 6).PietColor + (c div 6) * 6) mod 18
proc `light=`*(c:var PietColor,val:range[0..3]) =
  c = (((val + 6) mod 6).PietColor * 6.PietColor + (c mod 6)) mod 18
proc `nwb=`*(c:var PietColor,val:NWB) =
  c = case val:
    of White: WhiteNumber
    of Black: BlackNumber
    of None: c mod 18

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

proc getPietColor*(img:PNGResult,start:int): PietColor =
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


#[
  proc `$`*(self:PietColor): string =
    return case self.nwb:
      of None: "{self.hue}{('A'.int + self.light).char}".fmt
      of White: ".."
      of Black: "  "
]#
# Pietの命令について
type
  Order* = enum
    ErrorOrder,Push,Pop,
    Add,Sub,Mul,
    Div,Mod,Not,
    Greater,Pointer,Switch,
    Dup,Roll,InN,
    InC,OutN,OutC,
    Wall,Nop,Terminate
const orderBlock = [
  [ErrorOrder,Push,Pop],
  [Add,Sub,Mul],
  [Div,Mod,Not],
  [Greater,Pointer,Switch],
  [Dup,Roll,InN],
  [InC,OutN,OutC],
]

proc toChar*(order:Order):char =
  return case order:
    of Push: 'P'
    of Pop: 'p'
    of Add: '+'
    of Sub: '-'
    of Mul: '*'
    of Div: '/'
    of Mod: '%'
    of Not: '!'
    of Greater: '>'
    of Pointer: '&'
    of Switch: '?'
    of Dup: 'D'
    of Roll: 'R'
    of InN: 'i'
    of InC: 'I'
    of OutN: 'o'
    of OutC: 'O'
    of Nop: '_'
    of Wall: '|'
    of ErrorOrder: 'E'
    of Terminate: '$'

proc fromChar*(c:char) : Order =
  return case c:
    of 'P' : Push
    of 'p' : Pop
    of '+' : Add
    of '-' : Sub
    of '*' : Mul
    of '/' : Div
    of '%' : Mod
    of '!' : Not
    of '>' : Greater
    of '&' : Pointer
    of '?' : Switch
    of 'D' : Dup
    of 'R' : Roll
    of 'i' : InN
    of 'I' : InC
    of 'o' : OutN
    of 'O' : OutC
    of '_' : Nop
    of '|' : Wall
    of 'E' : ErrorOrder
    of '$' : Terminate
    else : ErrorOrder

proc decideOrder*(now,next:PietColor): Order =
  if next.nwb == Black or now.nwb == Black: return Wall # 解析のためには黒のこともある
  if next.nwb == White or now.nwb == White: return Nop
  let hueDiff = (6 + (next.hue - now.hue) mod 6) mod 6
  let lightDiff = (3 + (next.light - now.light) mod 3) mod 3
  return orderBlock[hueDiff][lightDiff]

proc decideNext*(now:PietColor,order:Order): PietColor =
  assert(not (order in [ErrorOrder,Terminate]))
  if order == Nop:
    result.nwb = White
    return
  result.nwb = None
  for h,byHue in orderblock:
    for l,o in byHue:
      if o != order: continue
      result.hue = now.hue + h
      result.light = now.light + l
      return




# Piet幾何計算用
type
  CC* = enum CCRight = false,CCLeft = true
  DP* = enum DPRight = 0,DPDown = 1,DPLeft = 2,DPUp = 3
  EightDirection*[T] = tuple[rightL,rightR,downL,downR,leftL,leftR,upL,upR:T]
proc newCC*():CC = CCLeft
proc newDP*():DP = DPRight
proc toggle*(cc: var CC) = cc = (not cc.bool).CC
proc toggle*(dp:var DP,n:int = 1) = dp = ((dp.int + n) mod 4).DP

iterator allCCDP*():(CC,DP) =
  yield (CCLeft ,DPRight)
  yield (CCRight,DPRight)
  yield (CCLeft ,DPDown)
  yield (CCRight,DPDown)
  yield (CCLeft ,DPLeft)
  yield (CCRight,DPLeft)
  yield (CCLeft ,DPUp)
  yield (CCRight,DPUp)

proc `[]=`*[T](self:var EightDirection[T],cc:CC,dp:DP,val:T) =
  case cc:
  of CCLeft:
    case dp:
    of DPRight: self.rightL = val
    of DPDown: self.downL = val
    of DPLeft: self.leftL = val
    of DPUp: self.upL = val
  of CCRight:
    case dp:
    of DPRight: self.rightR = val
    of DPDown: self.downR = val
    of DPLeft: self.leftR = val
    of DPUp: self.upR = val

proc `[]`*[T](val:EightDirection[T],cc:CC,dp:DP) : T =
  return case cc:
    of CCLeft:
      case dp:
      of DPRight: val.rightL
      of DPDown: val.downL
      of DPLeft: val.leftL
      of DPUp: val.upL
    of CCRight:
      case dp:
      of DPRight: val.rightR
      of DPDown: val.downR
      of DPLeft: val.leftR
      of DPUp: val.upR


proc toMinStr*(cc:CC,dp:DP):string =
  return case cc:
    of CCLeft:
      case dp:
      of DPRight: "→"
      of DPDown:  "↓"
      of DPLeft:  "←"
      of DPUp:    "↑"
    of CCRight:
      case dp:
      of DPRight: "R➜"
      of DPDown:  "R↓"
      of DPLeft:  "R←"
      of DPUp:    "R↑"
