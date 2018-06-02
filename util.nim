import sequtils,strutils,algorithm,math,future,macros,strformat,times

proc `*`*(str:string,n:int) : string =
  result = ""
  for i in 0..<n: result &= str

proc fscanf*(c: File, frmt: cstring) {.varargs, importc,header: "<stdio.h>".}

# 最初に指定した長さまでのStack
type Stack*[T] = ref object
  data:seq[T]
  size:int
  index:int
proc newStack*[T](size:int):Stack[T] =
  new(result)
  result.data = newSeq[T](size + 10)
  result.size = size
  result.index = -1
proc isEmpty*[T](self:var Stack[T]): bool = self.index < 0
proc isValid*[T](self:var Stack[T]):bool = self.index >= 0 and self.index < self.size
proc len*[T](self:var Stack[T]): int =
  if self.isEmpty(): return 0
  return self.index + 1
proc top*[T](self:var Stack[T]): T =
  assert self.isValid()
  return self.data[self.index]
proc pop*[T](self:var Stack[T]): T {.discardable.} =
  assert self.index >= 0
  result = self.top()
  self.index -= 1
proc push*[T](self:var Stack[T],elem:T) =
  self.index += 1
  if self.index < self.size:
    self.data[self.index] = elem
  else:
    self.data.add(elem)
    self.size += 1
proc `$`*[T](self:Stack[T]) : string = $(self.data[..self.index])



# 指定した行列
type Matrix*[T] = ref object
  data:seq[T]
  width*,height*: int
proc newMatrix*[T](width,height:int):Matrix[T] =
  new(result)
  result.data = newSeq[T](width * height)
  result.width = width
  result.height = height
proc `[]=`*[T](self:var Matrix[T],x,y:Natural,value:T) =
  self.data[x + self.width * y] = value
proc `[]`*[T](self:var Matrix[T],x,y:Natural): var T =
  return self.data[x + self.width * y]
proc `$`*[T](self:var Matrix[T]) :string=
  result = ""
  for y in 0..<self.height:
    for x in 0..<self.width:
      result &= $self[x,y]
    result &= "\n"

# 幾何計算用
type EightDirection*[T] = tuple[upR,upL,downR,downL,rightR,rightL,leftR,leftL:T]
proc zipCalc*[T,S,U](a:EightDirection[T],b:EightDirection[S],fn:proc(t:T,s:S):U) : EightDirection[U] =
  result[0] = fn(a[0],b[0])
  result[1] = fn(a[1],b[1])
  result[2] = fn(a[2],b[2])
  result[3] = fn(a[3],b[3])
  result[4] = fn(a[4],b[4])
  result[5] = fn(a[5],b[5])
  result[6] = fn(a[6],b[6])
  result[7] = fn(a[7],b[7])
proc map*[T,S](a:EightDirection[T],fn:proc(t:T):S) : EightDirection[S] =
  result[0] = fn(a[0])
  result[1] = fn(a[1])
  result[2] = fn(a[2])
  result[3] = fn(a[3])
  result[4] = fn(a[4])
  result[5] = fn(a[5])
  result[6] = fn(a[6])
  result[7] = fn(a[7])
type Pos* = tuple[x,y:int32]
proc `+`*(a,b:Pos) : Pos = (a.x + b.x, a.y + b.y)
const PosUp* = (0.int32,-1.int32)
const PosDown* = (0.int32,1.int32)
const PosRight* = (1.int32,0.int32)
const PosLeft* = (-1.int32,0.int32)

# stopWatch
type StopWatch* = tuple[sum,pre:float]
proc start*(self:var StopWatch) =
  self.pre = cpuTime()
proc stop*(self:var StopWatch) =
  self.sum += cpuTime() - self.pre
proc `$`*(self:StopWatch):string = fmt"{self.sum}s"

# unicode
#[

type WStringConverter {. importcpp:"std::wstring_convert",header:"<locale>",header:"<codecvt>" .} = object
proc newWStringConverter(): WStringConverter {. importcpp: "std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t>()" nodecl.}
type U16String{. importcpp:"std::u16string", header:"<locale>",header:"<codecvt>" .} = object
proc newU16String(a:int16 ): U16String {. importcpp: "std::u16string() + (char16_t)@", nodecl.}
type U8String{. importcpp:"std::u8string", header:"<locale>",header:"<codecvt>" .} = object
# proc newU8String(a:int ): U8String {. importcpp: "std::u8string() + @", nodecl.}
proc to_bytes(self:WStringConverter,u16str:U16String) :U8String {.importcpp: "#.to_bytes(@)",nodecl.}
proc from_bytes(self:WStringConverter,u8str:U8String) :U16String {.importcpp: "#.from_bytes(@)",nodecl.}
proc getU16(self:U16String): int16 {.importcpp: "#.at(0)",nodecl.}
proc getU8(self:U8String): int {.importcpp: "#.at(0)",nodecl.}

proc u16Tou8*(a:int16) :int  =
  let conv = newWStringConverter()
  let u16str = newU16String(a)
  return conv.to_bytes(u16str).getU8()

# proc u8Tou16*(a:int):int16  =
  # var u8str = newU8String(a)
  # return newWStringConverter().from_bytes(u8str).getU16()
int main()
{
  std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> converter;
  char16_t a = 12354;
  std::u16string str;
  // u8str : converter.to_bytes(str + a);
  // toInt (str + a)[0]
}
]#
