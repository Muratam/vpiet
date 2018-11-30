import packages/common
import packages/pietbase
import osproc
import graph

# seq[Edge] -> cpp


proc toCpp(order: OrderAndSize, debug: bool = false): string =
  proc impl(order: Order, size: int): string =
    case order
    of Add: return "add();"
    of Sub: return "sub();"
    of Mul: return "mul();"
    of Div: return "div_();"
    of Mod: return "mod();"
    of Greater: return "greater();"
    of Push: return "push({size});".fmt()
    of Pop: return "pop();"
    of Not: return "not_();"
    of Pointer: return "pointer();"
    of Switch: return "switch_();"
    of InC: return "inc();"
    of InN: return "inn();"
    of OutN: return "outn();"
    of OutC: return "outc();"
    of Dup: return "dup();"
    of Roll: return "roll();"
    of Terminate: return "return terminate();"
    else: return $order
  let code = impl(order.order, order.size)
  if debug: return "{code} debug(\"{code}\");".fmt()
  else: return code


proc compileToCppCode*(self: seq[Edge], debug: bool = false): string =
  const optimizedHeader = staticRead("template.cpp")
  result = optimizedHeader
  result &= "int main(){\n  start();\n"
  let outEdges = self.getOutEdgesIndexs()
  for i, outEdge in outEdges:
    if outEdge.len() == 0: continue
    let src = self[outEdge[0]].src
    result &= "a{src}:\n".fmt()
    let useBranches = self[outEdge[0]].branch >= 0
    if useBranches:
      # echo outEdge.mapIt(self[it].orderAndSizes[0].order)
      let order = self[outEdge[0]].orderAndSizes[0]
      result &= "  {order.toCpp(debug)}\n".fmt()
      for oe in outEdge:
        result &= "  if(next == {self[oe].branch}) goto a{src}_{oe};\n".fmt()
    for oe in outEdge:
      var orderAndSizes = self[oe].orderAndSizes
      if useBranches:
        result &= "a{src}_{oe}:\n".fmt()
        orderAndSizes = orderAndSizes[1..^1]
      for order in orderAndSizes:
        result &= "  {order.toCpp(debug)}\n".fmt()
      if self[oe].orderAndSizes[^1].order != Terminate:
        result &= "  goto a{self[oe].dst};\n".fmt()
  result &= "}"


proc executeAsCpp*(self: seq[Edge],
              cppFileName: string = "/tmp/piet.cpp",
              binFileName: string = "/tmp/piet.out") =
  let code = self.compileToCppCode()
  let f = open(cppFileName, fmWrite)
  f.write(code)
  f.close()
  let command = "gcc -O3 {cppFileName} -o {binFileName}".fmt()
  let (output, exitCode) = execCmdEx(command)
  if exitCode != 0:
    echo output
    return
  discard startProcess(binFileName, options = {poParentStreams}).waitForExit()
  discard startProcess("/usr/local/bin/code", args = [cppFileName], options = {})

