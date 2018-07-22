import common
import pietbase
import osproc
# indexを元に実行するPietCoreとは異なりorders を元に実行する
# WARN: いい感じになってきたらPietCoreも置き換えておきたい(?:リアルタイム実行？)
#     : if を自動で消したりPushの量を勝手に最適化したりしたい
#     : PietMap -> IndexTo の時点で Piet08 or KMC-Piet を選べる
#                                -> Viet -> Exec / Debug
# PietMap -> IndexTo -> PietCore         -> Exec
#                    -> Graph -> PietEmu -> Exec
# TODO:まずは普通に動かして,次にどんどん最適化して,最終的にPietCoreを置き換える
# 最適化しすぎると処理を追えなくなる？
# KMC-Piet <-> Piet08

# TODO: 生成したプログラムにバグがないか確かめる
#     : htmlserver /
#     : .vpiet -> .png -> .c を出来るか試す


type
  OrderWithInfo* = tuple[order:Order,size:int,dp:DP,cc:CC]
  PietProc* = tuple[
    orders:seq[OrderWithInfo],
    nexts:seq[int], # stack-top が 0..
    startCC:CC,
    startDP:DP,
  ]
  # 実行命令列と次に起こりうる遷移Index,
  PietEmu* = ref object
    dp*:DP
    cc*:CC
    stack*:Stack[int]
    nextDPCCIndex*:int

proc `$`*(self:OrderWithInfo):string =
  if self.order == Push : return "+{self.size}".fmt
  if self.order == Pointer : return "DP".fmt
  if self.order == Switch : return "CC".fmt
  if self.order == Wall : return "#".fmt
  if self.order == Terminate : return "END"
  if self.order == ErrorOrder : return "?{self.size}".fmt
  return $(self.order)
proc `$`*(self:seq[PietProc]):string =
  proc toStr(self:PietProc,i:int):string =
    result = ""
    result &= "{i} -> ".fmt() & self.nexts.join(",") & " | "#{self.startCC} {self.startDP}\n".fmt()
    const maxPlotOrder = 100
    if self.orders.len() > maxPlotOrder:
      let half = maxPlotOrder div 2 - 1
      result &= "{self.orders[0..half]} ... {self.orders[^half..^1]}".fmt
    else:
      result &= "{self.orders}".fmt
  var results : seq[string] = @[]
  for i in 0..<self.len():
    results &= self[i].toStr(i)
  return results.join("\n")

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




proc compileToCpp*(self:seq[PietProc]) : string =
  proc toCpp(order:OrderWithInfo) : string =
    case order.order
    of Add: return "add();"
    of Sub: return "sub();"
    of Mul: return "mul();"
    of Div: return "div_();"
    of Mod: return "mod();"
    of Greater: return "greater();"
    of Push: return "push({order.size});".fmt()
    of Pop: return "pop();"
    of Not: return "not_();"
    of Pointer: return "pointer();"
    of Switch:  return "switch_();"
    of InC: return "inc();"
    of InN: return "inn();"
    of OutN: return "outn();"
    of OutC: return "outc();"
    of Dup: return "dup();"
    of Roll: return "roll();"
    of Terminate: return "return terminate();"
    else:return $order.order
  const optimizedHeader =  staticRead("compile/optimized.cpp")
  result = optimizedHeader
  result &= "int main(){\n  start();\n"
  for i,pp in self:
    result &= "a{i}:\n".fmt()
    for order in pp.orders:
      result &= "  {order.toCpp()}\n".fmt()
      # result &= "debug(\"{order.toCpp()}\");".fmt()
    for n,next in pp.nexts:
      if n != pp.nexts.len() - 1 :
        result &= "  if(next == {n})".fmt()
      result &= "  goto a{next};\n".fmt()
  result &= "}"

proc compile*(self:seq[PietProc]) : string =
  block:
    let code = self.compileToCpp()
    discard existsOrCreateDir("nimcache")
    let f = open("nimcache/piet.cpp",fmWrite)
    f.write(code)
    f.close()
  # WARN: -O3
  let (output,exitCode) = execCmdEx("gcc nimcache/piet.cpp -o nimcache/piet.out")
  if exitCode != 0 : return output
  return ""
