import packages/common
import packages/pietbase
import nre
import tables

type
  # 外側に近い表現
  PasmType* = enum ExecOrder, MoveTerminate, Label, GoIf, Goto, ErrorPasmType
  PasmOrder* = tuple[pasmType: PasmType, order: Order, args: seq[string]]
  # info : Pushのときはsize を示す
  #      : isConnectのときは繋ぎたい場所(命令内でのindex表現)を示す
  EmbOrder* = tuple[isConnect: bool, order: Order, info: seq[int]]

proc `$`* (self: seq[seq[PasmOrder]]): string =
  result = ""
  for i, orders in self:
    result &= $i & "\n"
    for order in orders:
      if order.pasmType == ExecOrder:
        result &= $order.order
      else:
        result &= $order.pasmType
      result &= " " & ($order.args) & "\n"

proc `$`*(orders: seq[PasmOrder]): string =
  result = ""
  for order in orders:
    case order.pasmType:
    of ExecOrder:
      if order.order == Push: result &= "+" & order.args[0]
      else: result &= $order.order
    else: result &= $order.pasmType
    result &= " "

proc srcIndex*(order: EmbOrder): int =
  assert order.isConnect
  assert order.info.len == 2
  return order.info[0]

proc dstIndex*(order: EmbOrder): int =
  assert order.isConnect
  assert order.info.len == 2
  return order.info[1]

proc getPushSize*(order: EmbOrder): int =
  assert (not order.isConnect)
  assert order.info.len == 1
  return order.info[0]
proc newPushEmbOrder*(size: int): EmbOrder =
  assert size > 0
  return (false, Push, @[size])
proc newEmbOrder*(order: Order): EmbOrder = (false, order, @[])
proc newConnectOrder*(src, dst: int): EmbOrder =
  (true, ErrorOrder, @[src, dst])
proc `$`*(orders: seq[EmbOrder]): string =
  result = ""
  for order in orders:
    if order.isConnect:
      result &= fmt"CONN:{order.srcIndex}->{order.dstIndex}"
    else:
      if order.order == Push: result &= fmt"+{order.getPushSize()}"
      else: result &= $order.order
    result &= " "

proc interpretOrder*(orderName: string): Order =
  return case orderName.toLowerAscii():
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
    else: ErrorOrder

proc toPasmOrder*(order: seq[string]): PasmOrder =
  let errorResult: PasmOrder = (ErrorPasmType, ErrorOrder, @[])
  if order.len == 0: return errorResult
  let args = if order.len > 1: order[1..^1] else: @[]
  let orderName = order[0]
  let operation = orderName.interpretOrder()
  # Operation
  if operation != ErrorOrder:
    if operation == Push:
      if args.len != 1 or args[0] != "1":
        return errorResult
    if operation == Terminate:
      return (MoveTerminate, Terminate, args)
    return (ExecOrder, operation, args)
  # Label
  if orderName.endsWith(":"):
    let args = @[orderName.replace(":", "")]
    return (Label, ErrorOrder, args)
  # Go
  if orderName == "go":
    case args.len:
    of 1: return (Goto, ErrorOrder, args)
    of 2: return (GoIf, ErrorOrder, args)
    else: discard
  # Error
  return errorResult

proc labeling*(filename: string): seq[seq[PasmOrder]] =
  let f = open(filename, fmRead)
  defer: f.close()
  let lines = f.readAll().split("\n")
  var funs = newSeq[PasmOrder]()
  for line in lines:
    if line.len == 0: continue
    var fun = line.replace(re"#(.*)$", "").replace("  ", "").split(" ")
    funs.add(fun.toPasmOrder())
  if funs.len == 0 or funs[0].pasmType != Label:
    quit("invalid code")
  var names = newSeq[string]()
  result = @[]
  for fun in funs:
    if fun.pasmType == Label:
      names.add(fun.args[0])
      result.add(@[])
    else: result[^1].add(fun)
  var table = newTable[string, int]()
  for i, name in names: table[name] = i
  for i, res in result:
    for f, fun in res:
      if not (fun.pasmType in [Goto, GoIf]): continue
      for j, arg in fun.args:
        result[i][f].args[j] = $table[arg]

proc makeRandomOrders*(length: int): seq[PasmOrder] =
  randomize()
  proc getValidOrders(): seq[Order] =
    result = @[]
    for oo in orderBlock:
      for o in oo:
        if o notin [ErrorOrder, Terminate, Pointer, Switch]:
          result &= o
  result = @[]
  let orderlist = getValidOrders()
  for _ in 0..<length:
    let order = orderlist[rand(orderlist.len()-1)]
    let args = if order == Push: @["1"] else: @[]
    result &= (ExecOrder, order, args)
  result &= (MoveTerminate, Terminate, @[])
