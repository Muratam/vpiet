import stdimport
import hashes
# 指定した行列
type Matrix*[T] = ref object
  data*: seq[T]
  width*, height*: int
proc newMatrix*[T](width, height: int): Matrix[T] =
  new(result)
  result.data = newSeq[T](width * height)
  result.width = width
  result.height = height
proc hash*[T](self: Matrix[T]): Hash = self.data.hash()
proc deepCopy*[T](self: Matrix[T]): Matrix[T] =
  new(result)
  result.width = self.width
  result.height = self.height
  result.data = self.data
proc point*[T](self: var Matrix[T], fun: (proc (x, y: int): T)) =
  for x in 0..<self.width:
    for y in 0..<self.height:
      self[x, y] = fun(x, y)
proc getI*[T](self: Matrix[T], x, y: int): int {.
    inline.} = x + self.width * y
proc getX*[T](self: Matrix[T], i: int): int {.inline.} = i mod self.width
proc getY*[T](self: Matrix[T], i: int): int {.inline.} = i div self.width
proc getXY*[T](self: Matrix[T], i: int): tuple[x,
    y: int] {.inline.} = (self.getX(i), self.getY(i))
proc `[]=`*[T](self: var Matrix[T], x, y: Natural,
    value: T) = self.data[self.getI(x, y)] = value
proc `[]`*[T](self: Matrix[T], x, y: Natural): T = self.data[self.getI(x, y)]
proc `[]`*[T](self: var Matrix[T], x, y: Natural): var T = self.data[
    self.getI(x, y)]
proc `$`*[T](self: Matrix[T]): string =
  result = ""
  for y in 0..<self.height:
    for x in 0..<self.width:
      result &= $self[x, y]
    result &= "\n"
proc isIn*[T](mat: Matrix[T], x, y: int): bool =
  x >= 0 and y >= 0 and x < mat.width and y < mat.height
