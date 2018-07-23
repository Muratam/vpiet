import common
import nre
import pietbase
import tables
import nimPNG

#[
文法:
基本命令:
  push n
  pop add sub mul div mod not greater dup roll outn outc inn inc terminate
  <label>:
  go <label>
  go <label> <label> 条件に応じてジャンプ(jne / not not するのでトップは消える)
応用命令:
コメント: #
]#

type EMoveType* = enum
  Operation,MoveTerminate,Label,GoIf,Goto,ErrorVPietType
type OrderAndArgs* = tuple[order:EMoveType,operation:Order,args:seq[string]]

proc `$`* (self:seq[seq[OrderAndArgs]]):string =
  result = ""
  for i,orders in self:
    result &= $i & "\n"
    for order in orders:
      if order.order == Operation:
        result &= $order.operation
      else:
        result &= $order.order
      result &= " " & ($order.args) & "\n"

proc interpretVPietOrder*(orderName:string):Order =
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

proc toOrder*(order:seq[string]): OrderAndArgs=
  let errorResult :OrderAndArgs = (ErrorVPietType,ErrorOrder,@[])
  if order.len == 0 : return errorResult
  let args = if order.len > 1: order[1..^1] else : @[]
  let orderName = order[0]
  let operation = orderName.interpretVPietOrder()
  # Operation
  if operation != ErrorOrder :
    if operation == Push :
      if args.len != 1 or args[0] != "1" :
        return errorResult
    if operation == Terminate:
      return (MoveTerminate,Terminate,args)
    return (Operation,operation,args)
  # Label
  if orderName.endsWith(":"):
    let args = @[orderName.replace(":","")]
    return (Label,ErrorOrder,args)
  # Go
  if orderName == "go":
    case args.len :
    of 1: return (Goto,ErrorOrder,args)
    of 2: return (GoIf,ErrorOrder,args)
    else: discard
  # Error
  return errorResult

proc labeling*(filename:string): seq[seq[OrderAndArgs]] =
  let f = open(filename,fmRead)
  defer: f.close()
  let lines = f.readAll().split("\n")
  var funs = newSeq[OrderAndArgs]()
  for line in lines:
    if line.len == 0 : continue
    var fun = line.replace(re"#(.*)$","").replace("  ","").split(" ")
    funs.add(fun.toOrder())
  if funs.len == 0 or funs[0].order != Label :
    quit("invalid code")
  var names = newSeq[string]()
  result = @[]
  for fun in funs:
    if fun.order == Label:
      names.add(fun.args[0])
      result.add(@[])
    else: result[^1].add(fun)
  var table = newTable[string,int]()
  for i,name in names: table[name] = i
  for i,res in result:
    for f,fun in res:
      if not (fun.order in [Goto,GoIf]): continue
      for j,arg in fun.args:
        result[i][f].args[j] = $table[arg]



proc save*(self:Matrix[PietColor],filename:string) =
  var pixels = newString(3 * self.width * self.height)
  for x in 0..<self.width:
    for y in 0..<self.height:
      let (r,g,b)= self[x,y].toRGB()
      pixels[3 * (x + y * self.width) + 0] = cast[char](r)
      pixels[3 * (x + y * self.width) + 1] = cast[char](g)
      pixels[3 * (x + y * self.width) + 2] = cast[char](b)
  discard savePNG24(filename,pixels,self.width,self.height)

