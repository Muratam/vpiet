import common
import pietbase
import osproc
import makegraph
import visualize
import topiet
import pietize


if isMainModule:
  let params = commandLineParams()
  if params.len() == 0: quit("no params")
  if params.filterIt(it.startsWith("-")).len() == 0: quit("no options")
  let filenames = params.filterIt(not it.startsWith("-"))
  for filename in filenames:
    if filename.endsWith(".vpiet"):
      filename.labeling().toPiet().save()
    else:
      let graph = filename.newGraph()
      if params.anyIt(it == "-d"): graph.showGraph()
      if params.anyIt(it == "-e"): graph.executeAsCpp()
      if params.anyIt(it == "-v"): graph.saveAsVPiet()
