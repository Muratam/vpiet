import sequtils,strutils,algorithm,math,future,macros,strformat,times,random,os
export sequtils,strutils,algorithm,math,future,macros,strformat,times,random,os

# いわゆるcommonモジュール

proc `*`*(str:string,n:int) : string =
  result = ""
  for i in 0..<n: result &= str

proc fscanf*(c: File, frmt: cstring) {.varargs, importc,header: "<stdio.h>".}

# 最初に指定した長さまでのStack
type Stack*[T] = ref object
  data:seq[T]
  size:int
  index:int
proc newStack*[T](size:int = 64):Stack[T] =
  new(result)
  result.data = newSeq[T](size)
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
proc `[]`*[T](self: Matrix[T],x,y:Natural): T =
  return self.data[x + self.width * y]
proc `[]`*[T](self: var Matrix[T],x,y:Natural): var T =
  return self.data[x + self.width * y]
proc `$`*[T](self:var Matrix[T]) :string=
  result = ""
  for y in 0..<self.height:
    for x in 0..<self.width:
      result &= $self[x,y]
    result &= "\n"



type Pos* = tuple[x,y:int32]
proc `+`*(a,b:Pos) : Pos = (a.x + b.x, a.y + b.y)
const PosUp* = (0.int32,-1.int32)
const PosDown* = (0.int32,1.int32)
const PosRight* = (1.int32,0.int32)
const PosLeft* = (-1.int32,0.int32)
template `max=`*(x,y:typed):void = x = max(x,y)
template `min=`*(x,y:typed):void = x = min(x,y)
# stopWatch
type StopWatch* = tuple[sum,pre:float]
proc start*(self:var StopWatch) =
  self.pre = cpuTime()
proc stop*(self:var StopWatch) =
  self.sum += cpuTime() - self.pre
proc `$`*(self:StopWatch):string = fmt"{self.sum}s"
# Union Find
type UnionFindTree[T] = ref object
  parent: seq[int]
proc newUnionFindTree(n:int) : UnionFindTree =
  new(result)
  result.parent = newSeqWith(n,-1)
proc root(self:var UnionFindTree,x:int):int =
  if self.parent[x] < 0 : return x
  else:
    self.parent[x] = self.root(self.parent[x])
    return self.parent[x]
proc merge(self:var UnionFindTree,x,y:int):bool=
  var x = self.root(x)
  var y = self.root(y)
  if x == y : return false
  if self.parent[y] < self.parent[x] : (x,y) = (y,x)
  if self.parent[y] == self.parent[x] : self.parent[x] -= 1
  self.parent[y] = x
  return true

proc argmin*[T](arr:seq[T]):int =
  if arr.len() == 0 : return -1
  if arr.len() == 1 : return 0
  var mini = 0
  var mina = arr[0]
  for i,a in arr:
    if a >= mina : continue
    mina = a
    mini = i
  return mini

proc argmax*[T](arr:seq[T]):int =
  if arr.len() == 0 : return -1
  if arr.len() == 1 : return 0
  var maxi = 0
  var maxa = arr[0]
  for i,a in arr:
    if a <= maxa : continue
    maxa = a
    maxi = i
  return maxi
