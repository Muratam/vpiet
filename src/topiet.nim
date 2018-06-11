import common
import nre
import pietbase
import tables
import nimPNG
type VPietOrder = enum
  Push,Pop,Add,Sub,Mul,Div,Mod,
  Not,Greater,Dup,Roll,OutN,OutC,InN,InC,
  Terminate,Label,GoIf,Goto,ErrorOrder
type OrderAndArgs = tuple[order:VPietOrder,args:seq[string]]

proc toOrder(order:seq[string]): OrderAndArgs=
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

proc labeling(filename:string): seq[seq[OrderAndArgs]] =
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

proc toPietOrder(order:VPietOrder):Order =
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

proc `$` (self:seq[seq[OrderAndArgs]]):string =
  result = ""
  for i,orders in self:
    result &= $i & "\n"
    for order in orders:
      result &= $order & "\n"

proc toPiet(self:seq[seq[OrderAndArgs]]) :Matrix[PietColor]=
  let maxFunLen = self.mapIt(it.filterIt(not (it.order in[Goto,Goto])).len()).max()
  let width = maxFunLen + 5 + self.len() * 2
  let height = self.len() * 4 + 1
  var pietMap = newMatrix[PietColor](width,height)
  proc setMap(x,y:int,color:PietColor) =
    pietMap[self.len() * 2 + x + 2 ,2 + 4*y] = color
  # init
  for x in 0..<pietMap.width:
    for y in 0..<pietMap.height:
      pietMap[x,y] = WhiteNumber

  for y,orders in self:
    # 左のLabelジャンプ路
    block:
      # 最上部
      pietMap[2 * y + 2,0] = BlackNumber
      pietMap[2 * y + 2,1] = BlackNumber
      pietMap[2 * y + 1,0] = 0.PietColor
      # キャッチ
      pietMap[2*y+0,2+4*y] = 0.PietColor
      pietMap[2*y+1,2+4*y] = 0.PietColor
      pietMap[2*y+2,2+4*y] = 0.PietColor
      pietMap[2*y+0,1+4*y] = BlackNumber
      pietMap[2*y+2,1+4*y] = BlackNumber
      pietMap[2*y+0,3+4*y] = BlackNumber
      pietMap[2*y+2,3+4*y] = BlackNumber
    # 分岐
    var jumpOrder = ErrorOrder
    var jumpArgs = newSeq[int]()
    for x,order in orders:
      if order.order in [Terminate,Goto,GoIf]:
        jumpOrder = order.order
        jumpArgs = order.args.mapIt(it.parseInt())
        break
    if jumpOrder == Terminate:
      pietMap[width - 1,1 + y * 4] = BlackNumber
      pietMap[width - 1,2 + y * 4] = 0.PietColor
      pietMap[width - 1,3 + y * 4] = 0.PietColor
      pietMap[width - 2,3 + y * 4] = 0.PietColor
      pietMap[width - 3,3 + y * 4] = BlackNumber
      pietMap[width - 1,4 + y * 4] = BlackNumber
      pietMap[width - 2,4 + y * 4] = BlackNumber
      continue
    var nowColor = 0.PietColor
    pietMap[width - 2,2 + y * 4] = nowColor
    nowColor = nowColor.decideNext(Order.Push)
    pietMap[width - 1,2 + y * 4] = nowColor
    pietMap[width - 1,3 + y * 4] = nowColor
    nowColor = nowColor.decideNext(Order.Pointer)
    pietMap[width - 1,4 + y * 4] = nowColor
    case jumpOrder :
      of Goto:
        let x2 = 2 * jumpArgs[0] + 1
        let y2 = 4 + 4 * y
        pietMap[x2,y2] = 0.PietColor
        pietMap[x2-1,y2] = BlackNumber
      of GoIf:
        let y2 = 4 + 4 * y
        let minArg = min(jumpArgs[0],jumpArgs[1])
        let maxArg = max(jumpArgs[0],jumpArgs[1])
        pietMap[0+2*minArg,y2] = BlackNumber
        pietMap[1+2*minArg,y2] = 0.PietColor
        pietMap[2+2*maxArg,y2] = 0.PietColor
        pietMap[1+2*maxArg,y2] = 0.PietColor.decideNext(Order.Pointer)
        if jumpArgs[0] > jumpArgs[1]:
          pietMap[width - 2,4 + y * 4] = nowColor.decideNext(Order.Not)
      else: discard
  # 左端上
  pietMap[0,0] = 0.PietColor
  pietMap[0,1] = 0.PietColor
  pietMap[0,2] = 0.PietColor

  # write orders
  for y,orders in self:
    var nowColor = 0.PietColor
    setMap(0,y,nowColor)
    for x,order in orders:
      if order.order in [Terminate,Goto,GoIf]: continue
      let pietOrder = order.order.toPietOrder()
      nowColor = nowColor.decideNext(pietOrder)
      setMap(x+1,y,nowColor)
  return pietMap

proc `$`(pietMap:Matrix[PietColor]): string =
  result = ""
  for y in 0..<pietMap.height:
    for x in 0..<pietMap.width:
      let color = pietMap[x,y]
      let c =
        if color == WhiteNumber : '.'
        elif color == BlackNumber : '#'
        else: (color + 'a'.ord).chr
      result &= c
    result &= "\n"

proc save(self:Matrix[PietColor],filename:string) =
  var pixels = newString(3 * self.width * self.height)
  for x in 0..<self.width:
    for y in 0..<self.height:
      let (r,g,b)= self[x,y].toRGB()
      pixels[3 * (x + y * self.width) + 0] = cast[char](r)
      pixels[3 * (x + y * self.width) + 1] = cast[char](g)
      pixels[3 * (x + y * self.width) + 2] = cast[char](b)
  discard savePNG24(filename,pixels,self.width,self.height)


if isMainModule:
  let params = commandLineParams()
  if params.len() == 0: quit("no params")
  for filename in params:
    let labeled = labeling(filename)
    let pietMap = labeled.toPiet()
    pietMap.save("nimcache/piet.png")