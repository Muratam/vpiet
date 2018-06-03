import sequtils,strutils,algorithm,math,future,macros,strformat
import os,times
import pietmap
import util
import strscans

type
  CC* = enum CCRight = false,CCLeft = true
  DP* = enum DPRight = 0,DPDown = 1,DPLeft = 2,DPUp = 3
  Order* = enum
    ErrorOrder,Push,Pop,
    Add,Sub,Mul,
    Div,Mod,Not,
    Greater,Pointer,Switch,
    Dup,Roll,InN,
    InC,OutN,OutC,
    Wall,Nop,Terminate
  DirectedEdge* = tuple[index:int,order:Order]
  NextDirectedEdges* = EightDirection[DirectedEdge]
  IndexTo* = ref object
    # 実行に最低限必要な情報のみ保存(0番からスタート)
    # この段階で既に画像の情報は不要
    blockSize*: seq[int]
    nextEdges*: seq[NextDirectedEdges]
  DebugMode* = ref object
    # 通常は off だがDebug割り込み用に存在
    isOn: bool
    maxStep: int
    output: string
    input: string
    log: string
  PietCore* = ref object
    index: int
    dp:DP
    cc:CC
    stack: Stack[int]
    indexTo: IndexTo
    step:int
    lastCharIsNewLine: bool
    debug: DebugMode

proc toChar*(order:Order):char =
  return case order:
    of Push: 'P'
    of Pop: 'p'
    of Add: '+'
    of Sub: '-'
    of Mul: '*'
    of Div: '/'
    of Mod: '%'
    of Not: '!'
    of Greater: '>'
    of Pointer: '&'
    of Switch: '?'
    of Dup: 'D'
    of Roll: 'R'
    of InN: 'i'
    of InC: 'I'
    of OutN: 'o'
    of OutC: 'O'
    of Nop: '_'
    of Wall: '|'
    of ErrorOrder: 'E'
    of Terminate: '$'

proc fromChar*(c:char) : Order =
  return case c:
    of 'P' : Push
    of 'p' : Pop
    of '+' : Add
    of '-' : Sub
    of '*' : Mul
    of '/' : Div
    of '%' : Mod
    of '!' : Not
    of '>' : Greater
    of '&' : Pointer
    of '?' : Switch
    of 'D' : Dup
    of 'R' : Roll
    of 'i' : InN
    of 'I' : InC
    of 'o' : OutN
    of 'O' : OutC
    of '_' : Nop
    of '|' : Wall
    of 'E' : ErrorOrder
    of '$' : Terminate
    else : ErrorOrder



proc decideOrder(now,next:PietColor): Order =
  if next.nwb == Black or now.nwb == Black: return Wall # 解析のためには黒のこともある
  if next.nwb == White or now.nwb == White: return Nop
  let hueDiff = (6 + (next.hue - now.hue) mod 6) mod 6
  let lightDiff = (3 + (next.light - now.light) mod 3) mod 3
  return [
    [ErrorOrder,Push,Pop],
    [Add,Sub,Mul],
    [Div,Mod,Not],
    [Greater,Pointer,Switch],
    [Dup,Roll,InN],
    [InC,OutN,OutC],
  ][hueDiff][lightDiff]


proc getNextDirectedEdge(self:PietMap,color:PietColor,pos,dxdy:Pos): DirectedEdge =
  block: # non-white
    let (x,y) = pos + dxdy
    if x < 0 or y < 0 or x >= self.width or y >= self.height:
      return (-1,Wall)
    let nextIndex = self.indexMap[x,y]
    let nextColor = self.indexToPietColor[nextIndex]
    if nextColor.nwb != White:
      return (nextIndex,decideOrder(color,nextColor))
  # White WARN: ver.KMC-Piet
  var current = pos
  while true:
    current = current + dxdy
    let (cx,cy) = current
    if cx < 0 or cy < 0 or cx >= self.width or cy >= self.height:
      return (-1,Wall)
    let nextIndex = self.indexMap[cx,cy]
    let nextColor = self.indexToPietColor[nextIndex]
    if nextColor == BlackNumber: return (nextIndex,Wall)
    if nextColor == WhiteNumber: continue
    return (nextIndex,Nop)

proc getDiffEightPos(): EightDirection[Pos] =
  result.upR = PosUp
  result.upL = PosUp
  result.downR = PosDown
  result.downL = PosDown
  result.rightR = PosRight
  result.rightL = PosRight
  result.leftR = PosLeft
  result.leftL = PosLeft

proc newIndexTo*(self:PietMap): IndexTo =
  new(result)
  result.blockSize = self.indexToSize
  result.nextEdges = newSeq[NextDirectedEdges](self.maxIndex)
  let dXdYs = getDiffEightPos()
  for i in 0..< self.maxIndex:
    let endPos = self.indexToEndPos[i]
    let color = self.indexToPietColor[i]
    result.nextEdges[i] = zipCalc(endPos,dXdYs,
        (pos,dxdy) => self.getNextDirectedEdge(color,pos,dxdy))

proc newDebugMode*(isOn:bool = false,maxStep:int = 10000): DebugMode =
  new(result)
  result.isOn = isOn
  result.maxStep = maxStep
  result.output = ""
  result.input = ""
  result.log = ""

proc newPietCore*(indexTo:IndexTo,debug : DebugMode = newDebugMode()) : PietCore =
  result.new()
  result.indexTo = indexTo
  result.debug = debug


proc init(self:var PietCore) =
  self.index = 0
  self.dp = DPRight
  self.cc = CCLeft
  self.step = 0
  self.lastCharIsNewLine = true
  self.stack = newStack[int](4096)

proc chooseDirection[T](self:var PietCore,val:EightDirection[T]) : T =
  return case self.cc:
    of CCLeft:
      case self.dp:
        of DPRight: val.rightL
        of DPDown: val.downL
        of DPLeft: val.leftL
        of DPUp: val.upL
    of CCRight:
      case self.dp:
        of DPRight: val.rightR
        of DPDown: val.downR
        of DPLeft: val.leftR
        of DPUp: val.upR

proc toggleCC(self:var PietCore) =
  self.cc = (not self.cc.bool).CC
proc toggleDP(self:var PietCore,n:int = 1) =
  self.dp = ((self.dp.int + n) mod 4).DP

proc binaryFun(self:var PietCore,fn:proc(a,b:int):int) =
  if self.stack.len() < 2 : return
  let a = self.stack.pop()
  let b = self.stack.pop()
  self.stack.push(fn(a,b))

template unaryIt(self:var PietCore,op:untyped) =
  if self.stack.isEmpty() : return
  let it {.inject .} = self.stack.pop()
  op

proc output(self:var PietCore,str:string) =
  if not self.debug.isOn: stdout.write str
  else: self.debug.output &= str

proc doOrder(self:var PietCore,order:Order,size:int) =
  # WARN: 0除算 / 0商 は未定義
  # WARN: {Roll,InC,InN} は手抜きの可能性あり
  # WARN: debugMode でのInが手抜き
  case order
    of Add: self.binaryFun((a,b)=>b+a)
    of Sub: self.binaryFun((a,b)=>b-a)
    of Mul: self.binaryFun((a,b)=>b*a)
    of Div: self.binaryFun((a,b)=>b div a)
    of Mod: self.binaryFun((a,b)=>b mod a)
    of Greater: self.binaryFun((a,b)=> (if b > a : 1 else: 0))
    of Push: self.stack.push(size)
    of Pop: self.unaryIt((discard))
    of Not: self.unaryIt(self.stack.push(if it > 0 : 0 else: 1))
    of Pointer: self.unaryIt(self.toggleDP(it))
    of Switch: self.unaryIt(if it mod 2 == 1 : self.toggleCC())
    of InC: self.stack.push(stdin.readChar().int) # WARN:
    of InN:
      var x :int
      stdin.fscanf("%d",addr x) # WARN:
      self.stack.push(x)
    of OutN:
      self.unaryIt( self.output fmt"{it}" )
      self.lastCharIsNewLine = false
    of OutC:
      self.unaryIt:
        if it < 256: self.output fmt"{it.char}"
        else: self.output fmt"[c:{it}]"
        self.lastCharIsNewLine = it.char == '\n'
    of Dup:
      if not self.stack.isEmpty():
        self.stack.push(self.stack.top())
    of Roll:
      if self.stack.len() >= 2 :
        let a = self.stack.pop() # a 回転
        var b = self.stack.pop() # 深さ b まで
        b = b.min(self.stack.len())
        var roll = newSeq[int]()
        for i in 0..<b: roll.add(self.stack.pop())
        for i in 0..<b: self.stack.push(roll[(i + a) mod b])
    else: discard
  # stdout.write order
  # stdout.write ":"
  # echo self.stack

proc nextStep(self:var PietCore): bool =
  self.step += 1
  let nextEdge = self.indexTo.nextEdges[self.index]
  for i in 0..<8: # 8方向全て見る
    let (index,order) = self.chooseDirection(nextEdge)
    if order == Terminate: return false
    if order != Wall:
      self.doOrder(order,self.indexTo.blockSize[self.index])
      self.index = index
      return true
    if i mod 2 == 0: self.toggleCC()
    else : self.toggleDP()
  return false

proc exec*(self:var PietCore) =
  self.init()
  while self.nextStep():
    if not self.debug.isOn: continue
    if self.debug.maxStep > 0 and self.step > self.debug.maxStep:
      self.debug.log &= "Quit: over {self.debug.maxStep} step\n".fmt
      break
  if not self.lastCharIsNewLine: self.output("\n")


if isMainModule:
  # Pietを実行
  let params = os.commandLineParams()
  if params.len() == 0: quit("no params")
  for filename in params:
    var core = filename.newPietMap().newIndexTo().newPietCore()
    core.exec()

