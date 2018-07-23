import common
import pietbase
import osproc
import makegraph


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



proc compileToCppCode(self:seq[PietProc]) : string =
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

proc drawGraph(self:seq[PietProc],showAll:bool) : string =
  var dot = """digraph pietgraph {
    graph [
      charset = "UTF-8", fontname = "Menlo", style = "filled"
    ];
    node [
      shape = box, fontname = "Menlo", style = "filled",
      fontcolor = "#222222", fillcolor = "#ffffff"
    ];
  """.replace("\n  ","\n")
  for i,pp in self:
    let maxShow = if showAll:100 else:6
    let order =
      if pp.orders.len() == 1: $(pp.orders[0])
      elif pp.orders.len() == 0: ""
      elif pp.orders.len() > maxShow:
        "{pp.orders[0..<(maxShow div 2)]} ~\n {pp.orders[^(maxShow div 2)..^1]}".fmt()
      else : "{pp.orders}".fmt()
    let ccdp = "{toMinStr(pp.startCC,pp.startDP)}".fmt
    var content = "({pp.orders.len()}) {ccdp}\n{order}".fmt
    if i == 0: content = "START\n" & content
    dot &= fmt"""  a{i} [label = "a{i}{content}"];""" & "\n"
    for n in 0..<pp.nexts.len():
      let next = pp.nexts[n]
      if next < 0: continue # ダミーノード()
      let label = if n == 0 : "" else: $n
      dot &= fmt"""  a{i} -> a{next} [label = "{label}"];""" & "\n"
  dot &= "}"
  return dot

proc executeAsCpp*(self:seq[PietProc],
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

proc showGraph*(self:seq[PietProc],
                showAll:bool=true,
                dotFileName:string="/tmp/piet.dot",
                pngFileName:string="/tmp/piet.png") =
  let dot = self.drawGraph(showAll)
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
    let graph = filename.newGraph(optimize=true)
    if draw: graph.showGraph()
    if execute : graph.executeAsCpp()