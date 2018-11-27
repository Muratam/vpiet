import stdimport
# Union Find
type UnionFindTree[T] = ref object
  parent: seq[int]
proc newUnionFindTree*(n:int) : UnionFindTree =
  new(result)
  result.parent = newSeqWith(n,-1)
proc root(self:var UnionFindTree,x:int):int =
  if self.parent[x] < 0 : return x
  else:
    self.parent[x] = self.root(self.parent[x])
    return self.parent[x]
proc merge*(self:var UnionFindTree,x,y:int):bool=
  var x = self.root(x)
  var y = self.root(y)
  if x == y : return false
  if self.parent[y] < self.parent[x] : (x,y) = (y,x)
  if self.parent[y] == self.parent[x] : self.parent[x] -= 1
  self.parent[y] = x
  return true