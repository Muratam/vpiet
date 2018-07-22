import common
import nre
import pietbase
import tables
import nimPNG

type VPietOrder* = enum
  Push,Pop,Add,Sub,Mul,Div,Mod,
  Not,Greater,Dup,Roll,OutN,OutC,InN,InC,
  Terminate,Label,GoIf,Goto,ErrorOrder
type OrderAndArgs* = tuple[order:VPietOrder,args:seq[string]]

proc toPietOrder*(order:VPietOrder):Order =
  return case order :
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
    of Terminate:Order.Terminate
    else:Order.ErrorOrder

proc `$`* (self:seq[seq[OrderAndArgs]]):string =
  result = ""
  for i,orders in self:
    result &= $i & "\n"
    for order in orders:
      result &= $order & "\n"


proc toOrder*(order:seq[string]): OrderAndArgs=
  if order.len == 0 : return (ErrorOrder,@[])
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
  else: ErrorOrder
  if result.order == Push :
    if result.args.len != 1: result.order = ErrorOrder
    if result.args[0] != "1" : result.order = ErrorOrder
    return
  if result.order != ErrorOrder: return
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

