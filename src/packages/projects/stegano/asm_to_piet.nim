import packages/common
import packages/pietbase
import nre
import tables
import osproc
import nimPNG

# ASM -> 回路図Piet

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



proc save*(self:Matrix[PietColor],filename:string="/tmp/piet.png",codelSize:int=1,open:bool=true) =
  var pixels = newString(3 * self.width * self.height * codelSize * codelSize)
  for x in 0..<self.width:
    for y in 0..<self.height:
      let (r,g,b)= self[x,y].toRGB()
      for xi in 0..<codelSize:
        for yi in 0..<codelSize:
          let nx = x * codelSize + xi
          let ny = y * codelSize + yi
          let pos = nx + ny * self.width*codelSize
          pixels[3 * pos + 0] = cast[char](r)
          pixels[3 * pos + 1] = cast[char](g)
          pixels[3 * pos + 2] = cast[char](b)
  discard savePNG24(filename,pixels,self.width*codelSize,self.height*codelSize)
  if open : discard startProcess("/usr/bin/open",args=[filename],options={})


proc toPiet*(self:seq[seq[OrderAndArgs]]) :Matrix[PietColor]=
  let maxFunLen = self.mapIt(it.filterIt(not (it.order in[Goto,Goto])).len()).max()
  let width = maxFunLen + 8 + self.len() * 2
  let height = self.len() * 4 + 1
  var pietMap = newMatrix[PietColor](width,height)
  proc setMap(x,y:int,color:PietColor) =
    pietMap[self.len() * 2 + x + 4 ,2 + 4*y] = color
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
      pietMap[0,1+4*y] = BlackNumber
      pietMap[0,2+4*y] = 0.PietColor
      pietMap[0,3+4*y] = BlackNumber

    # 分岐
    var jumpOrder = ErrorVPietType
    var jumpArgs = newSeq[int]()
    for x,order in orders:
      if order.order in [MoveTerminate,Goto,GoIf]:
        jumpOrder = order.order
        jumpArgs = order.args.mapIt(it.parseInt())
        break
    if jumpOrder == MoveTerminate:
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
        nowColor = nowColor.decideNext(Order.Not)
        pietMap[width - 2,4 + y * 4] = nowColor
        nowColor = nowColor.decideNext(Order.Not)
        pietMap[width - 3,4 + y * 4] = nowColor
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
    pietMap[self.len() * 2 + 2 ,2 + 4*y] = nowColor
    pietMap[self.len() * 2 + 2 ,1 + 4*y] = nowColor
    pietMap[self.len() * 2 + 3 ,1 + 4*y] = BlackNumber
    setMap(0,y,nowColor)
    for x,order in orders:
      if order.order in [MoveTerminate,Goto,GoIf]: continue
      let pietOrder = order.operation
      nowColor = nowColor.decideNext(pietOrder)
      setMap(x+1,y,nowColor)
  return pietMap



if isMainModule:
  for filename in commandLineParams():
    filename.labeling().toPiet().save()