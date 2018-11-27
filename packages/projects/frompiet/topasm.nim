import packages/common
import packages/pietbase
import osproc
import graph

# seq[Edge] -> ASM


proc toPasm(order:OrderAndSize,debug:bool=false) : string =
  proc impl(order:Order,size:int):string =
    case order
    of Add: return "add"
    of Sub: return "sub"
    of Mul: return "mul"
    of Div: return "div"
    of Mod: return "mod"
    of Greater: return "greater"
    of Push: return "push {size}".fmt()
    of Pop: return "pop"
    of Not: return "not"
    of Pointer: return "pop"
    of Switch:  return "pop"
    of InC: return "inc"
    of InN: return "inn"
    of OutN: return "outn"
    of OutC: return "outc"
    of Dup: return "dup"
    of Roll: return "roll"
    of Terminate: return "terminate"
    else:return $order
  return impl(order.order,order.size)


proc compileToPasmCode*(self:seq[Edge]):string =
  result = ""
  let outEdges = self.getOutEdgesIndexs()
  for i ,outEdge in outEdges:
    if outEdge.len() == 0 : continue
    for i,oe in outEdge:
      let src = self[outEdge[0]].src
      let dst = self[oe].dst
      var orderAndSizes = self[oe].orderAndSizes
      if self[oe].branch >= 0:
        result &= "a{src}_{oe}:\n".fmt()
        orderAndSizes = orderAndSizes[1..^1]
      elif i == 0:
        result &= "a{src}:\n".fmt()
      for order in orderAndSizes:
        result &= "  {order.toPasm()}\n".fmt()
      if self[oe].orderAndSizes[^1].order != Terminate:
        let dstEdges = outEdges[self[oe].dst]
        case dstEdges.len():
        of 1: result &= "  go a{self[oe].dst}\n".fmt()
        of 2: result &= "  go " & dstEdges.mapIt("a{dst}_{it}".fmt()).join(" ") & "\n"
        else: quit("invalid branch")


proc saveAsPasm*(self:seq[Edge],
              pasmFileName:string="/tmp/piet.asm") =
  let code = self.compileToPasmCode()
  let f = open(pasmFileName,fmWrite)
  f.write(code)
  f.close()
  discard startProcess("/usr/local/bin/code",args=[pasmFileName],options={})


