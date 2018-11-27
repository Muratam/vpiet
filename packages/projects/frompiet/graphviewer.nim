import packages/common
import packages/pietbase
import osproc
import graph

# seq[Edge] -> graph view

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