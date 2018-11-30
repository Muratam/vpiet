import stdimport
template `max=`*(x, y: typed): void = x = max(x, y)
template `min=`*(x, y: typed): void = x = min(x, y)
proc argmin*[T](arr: seq[T]): int =
  if arr.len() == 0: return -1
  if arr.len() == 1: return 0
  var mini = 0
  var mina = arr[0]
  for i, a in arr:
    if a >= mina: continue
    mina = a
    mini = i
  return mini
proc argmax*[T](arr: seq[T]): int =
  if arr.len() == 0: return -1
  if arr.len() == 1: return 0
  var maxi = 0
  var maxa = arr[0]
  for i, a in arr:
    if a <= maxa: continue
    maxa = a
    maxi = i
  return maxi

