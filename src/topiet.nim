import common
import nre
import pietbase
type VPietOrder = enum
  Push,Pop,Add,Sub,Mul,Div,Mod,
  Not,Greater,Dup,Roll,OutN,OutC,InN,InC,
  Terminate,Label,GoIf,Goto,Error
type OrderAndArgs = tuple[order:VPietOrder,args:seq[string]]
type LabeledOrders = tuple[name:string,orders:seq[OrderAndArgs]]

proc toOrder(order:seq[string]): OrderAndArgs=
  if order.len == 0 : return (Error,@[])
  result.args = if order.len > 1: order[1..^1] else : @[]
  let orderName = order[0].toLowerAscii()
  result.order = case orderName:
  of "push": Push
  of "pop": Pop
  of "add": Add
  of "sub": Sub
  of "mul": Mul
  of "div": Div
  of "mod": Mod
  of "not": Not
  of "greater": Greater
  of "dup": Dup
  of "roll": Roll
  of "outn": OutN
  of "outc": OutC
  of "inn": InN
  of "inc": InC
  of "terminate": Terminate
  of "end": Terminate
  else: Error
  if result.order == Push :
    if result.args.len != 1: result.order = Error
    if result.args[0] != "1" : result.order = Error
    return
  if result.order != Error: return
  if orderName.endsWith(":"):
    result.order = Label
    result.args = @[orderName.replace(":","")]
    return
  if orderName != "go": return
  if result.args.len == 1 :
    result.order = Goto
    return
  if result.args.len == 2:
    result.order = GoIf
    return

proc labeling(filename:string): seq[LabeledOrders] =
  let f = open(filename,fmRead)
  defer: f.close()
  let lines = f.readAll().split("\n")
  var funs = newSeq[OrderAndArgs]()
  for line in lines:
    if line.len == 0 : continue
    var fun = line.replace(re"#(.*)$","").replace("  ","").split(" ")
    funs.add(fun.toOrder())
  if funs.len == 0 or funs[0].order != Label : quit("invalid code")
  result = @[]
  for fun in funs:
    if fun.order == Label: result.add((fun.args[0],@[]))
    else: result[^1].orders.add(fun)
proc `$` (self:seq[LabeledOrders]):string =
  result = ""
  for orders in self:
    result &= orders.name & "\n"
    for order in orders.orders:
      result &= $order & "\n"

proc toPiet(self:seq[LabeledOrders]) =
  var strmap = ""
  for orders in self:
    strmap &= orders.name & ":"
    var nowColor = 0.PietColor
    for order in orders.orders:
      if order.order == Terminate:
        strmap &= "#"
        continue
      if order.order == Goto:
        strmap &= " -> " & order.args[0]
        continue
      if order.order == GoIf:
        strmap &= " -> {order.args[0]},{order.args[1]}".fmt
        continue
      let pietOrder = case order.order :
        of Push:Order.Push
        of Pop:Order.Pop
        of Add:Order.Add
        of Sub:Order.Sub
        of Mul:Order.Mul
        of Div:Order.Div
        of Mod:Order.Mod
        of Not:Order.Not
        of Greater:Order.Greater
        of Dup:Order.Dup
        of Roll:Order.Roll
        of OutN:Order.OutN
        of OutC:Order.OutC
        of InN:Order.InN
        of InC:Order.InC
        else:Order.ErrorOrder
      strmap &= (nowColor + 'a'.ord).chr
      nowColor = nowColor.decideNext(pietOrder)
    strmap &= & "\n"
  echo strmap


if isMainModule:
  let params = commandLineParams()
  if params.len() == 0: quit("no params")
  for filename in params:
    let labeled = labeling(filename)
    labeled.toPiet()