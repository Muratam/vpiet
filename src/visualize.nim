import common
import pietbase
import osproc
import makegraph


proc toCpp(order:OrderAndSize,debug:bool=false) : string =
  proc impl(order:Order,size:int):string =
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
    of Switch:  return "switch_();"
    of InC: return "inc();"
    of InN: return "inn();"
    of OutN: return "outn();"
    of OutC: return "outc();"
    of Dup: return "dup();"
    of Roll: return "roll();"
    of Terminate: return "return terminate();"
    else:return $order
  let code = impl(order.order,order.size)
  if debug: return "{code} debug(\"{code}\");".fmt()
  else: return code


proc toVPiet(order:OrderAndSize,debug:bool=false) : string =
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



proc compileToCppCode(self:seq[Edge],debug:bool=false) : string =
  const optimizedHeader =  staticRead("compile/optimized.cpp")
  result = optimizedHeader
  result &= "int main(){\n  start();\n"
  let outEdges = self.getOutEdgesIndexs()
  for i ,outEdge in outEdges:
    if outEdge.len() == 0 : continue
    let src = self[outEdge[0]].src
    result &= "a{src}:\n".fmt()
    let useBranches = self[outEdge[0]].branch >= 0
    if useBranches:
      echo outEdge.mapIt(self[it].orderAndSizes[0].order)
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


proc executeAsCpp*(self:seq[Edge],
              cppFileName:string="/tmp/piet.cpp",
              binFileName:string="/tmp/piet.out") =
  let code = self.compileToCppCode()
  let f = open(cppFileName,fmWrite)
  f.write(code)
  f.close()
  let command = "gcc -O3 {cppFileName} -o {binFileName}".fmt()
  let (output,exitCode) = execCmdEx(command)
  if exitCode != 0 :
    echo output
    return
  discard startProcess(binFileName,options={poParentStreams}).waitForExit()
  discard startProcess("/usr/local/bin/code",args=[cppFileName],options={})


proc compileToVPietCode(self:seq[Edge]):string =
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
        result &= "  {order.toVpiet()}\n".fmt()
      if self[oe].orderAndSizes[^1].order != Terminate:
        let dstEdges = outEdges[self[oe].dst]
        case dstEdges.len():
        of 1: result &= "  go a{self[oe].dst}\n".fmt()
        of 2: result &= "  go " & dstEdges.mapIt("a{dst}_{it}".fmt()).join(" ") & "\n"
        else: quit("invalid branch")



proc drawGraph(self:seq[Edge]) : string =
  var dot = """digraph pietgraph {
    graph [
      charset = "UTF-8", fontname = "Menlo", style = "filled"
    ];
    node [
      shape = box, fontname = "Menlo", style = "filled",
      fontcolor = "#222222", fillcolor = "#ffffff"
    ];
    a0 [label=""]
  """.replace("\n  ","\n")
  for info in self:
    let (src,dst,orderAndSizes,branch) = info
    var label = ""
    for i,orderAndSize in orderAndSizes:
      let (order,size) = orderAndSize
      if order != Push: label &= "{order} ".fmt()
      else: label &= "+{size} ".fmt()
      if i mod 6 == 0 : label &= "\n"
    let nodeLabel = if src == 0 : "START\na{src}".fmt() else: "a{src}".fmt()
    dot &= " a{src} [label = \"{nodeLabel}\"];\n".fmt()
    let top = if branch < 0 : "" else: ($branch) & ":"
    let dstNode = if orderAndSizes[^1].order == Terminate : "END" else: "a{dst}".fmt()
    dot &= fmt"""  a{src} -> {dstNode} [label = "{top}{label}"];""" & "\n"
  dot &= "}"
  return dot

proc showGraph*(self:seq[Edge],
                dotFileName:string="/tmp/piet.dot",
                pngFileName:string="/tmp/piet.png") =
  let dot = self.drawGraph()
  let f = open(dotFileName,fmWrite)
  f.write(dot)
  f.close()
  let command = "dot -Tpng {dotFileName} -o {pngFileName}".fmt()
  let (output,exitCode) = execCmdEx(command)
  if exitCode != 0 :
    echo output
    return
  discard startProcess("/usr/bin/open",args=[pngFileName],options={})

if isMainModule:
  let params = commandLineParams()
  if params.len() == 0: quit("no params")
  if params.filterIt(it.startsWith("-")).len() == 0: quit("no options")
  var execute = false
  var draw = false
  for param in params:
    if "-e" in param : execute = true
    if "-d" in param : draw = true
  for filename in params:
    if filename.startsWith("-") : continue
    let graph = filename.newGraph()
    echo graph.compileToVPietCode()
    if draw: graph.showGraph()
    if execute : graph.executeAsCpp()
