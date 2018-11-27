import stdimport
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
proc deepCopy*[T](self:Stack[T]) : Stack[T] =
  new(result)
  result.size = self.size
  result.index = self.index
  result.data = self.data

proc isEmpty*[T](self:Stack[T]): bool = self.index < 0
proc isValid*[T](self:Stack[T]):bool = self.index >= 0 and self.index < self.size
proc len*[T](self:Stack[T]): int =
  if self.isEmpty(): return 0
  return self.index + 1
proc top*[T](self:Stack[T]): T =
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
