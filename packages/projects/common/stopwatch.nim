import stdimport
type StopWatch* = ref object
  sum, pre: float
  call: int
proc reset*(self: var StopWatch) =
  self.sum = 0.0
  self.pre = 0.0
  self.call = 0
proc start*(self: var StopWatch) =
  self.pre = cpuTime()
proc stop*(self: var StopWatch): StopWatch {.discardable.} =
  self.sum += cpuTime() - self.pre
  self.call += 1
  return self
proc newStopWatch*(): StopWatch =
  new(result)
  result.sum = 0.0
  result.pre = 0.0
  result.call = 0
  result.start()
proc `$`*(self: StopWatch): string = fmt"{self.sum}s ({self.call})"

template calcTime*(op: untyped): untyped =
  var sw = newStopWatch()
  op
  echo sw.stop()
