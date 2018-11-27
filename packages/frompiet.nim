import projects/frompiet/[topasm,tocpp,graphviewer,graph,pietmap,indexto]
export topasm,tocpp,graphviewer,graph,pietmap,indexto

import common

if isMainModule:
  let params = commandLineParams()
  if params.len() == 0: quit("no params")
  if params.filterIt(it.startsWith("-")).len() == 0: quit("no options")
  var execute = false
  var draw = false
  var topasm = false
  for param in params:
    if "-e" in param : execute = true
    if "-d" in param : draw = true
    if "-v" in param : topasm = true
  for filename in params:
    if filename.startsWith("-") : continue
    let graph = filename.newGraph()
    if draw: graph.showGraph()
    if execute : graph.executeAsCpp()
    if topasm : graph.saveAsPasm()
