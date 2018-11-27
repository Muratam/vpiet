# Piet幾何計算用
type
  CC* = enum CCRight = false,CCLeft = true
  DP* = enum DPRight = 0,DPDown = 1,DPLeft = 2,DPUp = 3
  EightDirection*[T] = tuple[rightL,rightR,downL,downR,leftL,leftR,upL,upR:T]
proc newCC*():CC = CCLeft
proc newDP*():DP = DPRight
proc newEightDirection*[T](t:T):EightDirection[T] = (t,t,t,t,t,t,t,t)
proc toggle*(cc: var CC) = cc = (not cc.bool).CC
proc toggle*(dp:var DP,n:int = 1) = dp = ((dp.int + n) mod 4).DP
proc getdXdY*(dp:DP): tuple[x,y:int] =
  return case dp:
    of DPRight: (1,0)
    of DPLeft: (-1,0)
    of DPDown: (0,1)
    of DPUp: (0,-1)

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
