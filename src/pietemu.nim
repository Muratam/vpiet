import common
import pietbase
import osproc
import pietproc

type
  # 実行命令列と次に起こりうる遷移Index,
  PietEmu* = ref object
    dp*:DP
    cc*:CC
    stack*:Stack[int]
    nextDPCCIndex*:int


proc newPietEmu*(dp:DP,cc:CC):PietEmu =
  new(result)
  result.dp = dp
  result.cc = cc
  result.stack = newStack[int]()
  result.nextDPCCIndex = -1
proc step*(self:PietEmu,info:OrderWithInfo) : bool =
  result = true
  self.cc = info.cc
  self.dp = info.dp
  template binaryIt(op) =
    if self.stack.len() < 2 :
      return false
    let a {.inject.}= self.stack.pop()
    let b {.inject.}= self.stack.pop()
    op
  template unaryIt(op) =
    if self.stack.len() < 1 :
      return false
    let it {.inject.} = self.stack.pop()
    op
  self.nextDPCCIndex = 0
  case info.order
  of Add: binaryIt(self.stack.push(b + a))
  of Sub: binaryIt(self.stack.push(b - a))
  of Mul: binaryIt(self.stack.push(b * a))
  of Div: binaryIt(self.stack.push(b div a)) # 0 除算は無視すべき
  of Mod: binaryIt(self.stack.push(b mod a))
  of Greater: binaryIt(self.stack.push(if b > a : 1 else: 0))
  of Push: self.stack.push(info.size)
  of Pop: unaryIt((discard))
  of Not: unaryIt(self.stack.push(if it > 0 : 0 else: 1))
  of Pointer: unaryIt((self.nextDPCCIndex = (((it mod 4) + 4) mod 4)))
  of Switch:  unaryIt((self.nextDPCCIndex = (((it mod 2) + 2) mod 2)))
  of InC: return false #
  of InN: return false
  of OutN: unaryIt((discard))
  of OutC: unaryIt((discard))
  of Dup: unaryIt((self.stack.push(it);self.stack.push(it)))
  of Roll:
    if self.stack.len() < 2 : return false
    let a = self.stack.pop() # a 回転
    var b = self.stack.pop() # 深さ b まで
    if b > self.stack.len(): return false
    var roll = newSeq[int]()
    for i in 0..<b: roll.add(self.stack.pop())
    for i in 0..<b: self.stack.push(roll[(- i - 1 + a + b) mod b])
  of Wall:discard
  else:discard
proc execSteps*(emu:var PietEmu,orders:seq[OrderWithInfo]): bool =
  for order in orders:
    if not emu.step(order): return false
  return true
