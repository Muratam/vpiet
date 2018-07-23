import common
import pietbase
import osproc

type
  OrderWithInfo* = tuple[order:Order,size:int,dp:DP,cc:CC]
  PietProc* = tuple[
    orders:seq[OrderWithInfo],
    nexts:seq[int], # stack-top が 0..
    startCC:CC,
    startDP:DP,
  ]
  PietProcs* = seq[PietProc]


proc `$`*(self:OrderWithInfo):string =
  if self.order == Push : return "+{self.size}".fmt
  if self.order == Pointer : return "DP".fmt
  if self.order == Switch : return "CC".fmt
  if self.order == Wall : return "#".fmt
  if self.order == Terminate : return "END"
  if self.order == ErrorOrder : return "?{self.size}".fmt
  return $(self.order)


proc `$`*(self:PietProcs):string =
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

proc compileToCpp*(self:PietProcs) : string =
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

proc compile*(self:PietProcs) : string =
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