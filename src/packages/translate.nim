

if isMainModule:
  let params = commandLineParams()
  if params.len() == 0: quit("no params")
  if params.filterIt(it.startsWith("-")).len() == 0: quit("no options")
  var execute = false
  var draw = false
  var vpiet = false
  for param in params:
    if "-e" in param : execute = true
    if "-d" in param : draw = true
    if "-v" in param : vpiet = true
  for filename in params:
    if filename.startsWith("-") : continue
    let graph = filename.newGraph()
    if draw: graph.showGraph()
    if execute : graph.executeAsCpp()
    if vpiet : graph.saveAsAsm()
