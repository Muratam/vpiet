
import common
import pietmap, indexto
export pietmap, indexto


type

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
    of Pointer: self.unaryIt(self.dp.toggle(it))
    of Switch: self.unaryIt(if it mod 2 == 1 : self.cc.toggle())
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
    let (index,order) = nextEdge.chooseDirection(self.cc,self.dp)
    if order == Terminate: return false
    if order != Wall:
      self.doOrder(order,self.indexTo.blockSize[self.index])
      self.index = index
      return true
    if i mod 2 == 0: self.cc.toggle()
    else : self.dp.toggle(1)
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
  let params = commandLineParams()
  if params.len() == 0: quit("no params")
  for filename in params:
    var core = filename.newPietMap().newIndexTo().newPietCore()
    core.exec()

