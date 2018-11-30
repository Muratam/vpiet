import packages/common
import packages/pietbase
import pasm

const EPS* = 1e12.int
const dxdys* = [(0, 1), (0, -1), (1, 0), (-1, 0)]


proc makeRandomPietColorMatrix*(width, height: int): Matrix[PietColor] =
  randomize()
  result = newMatrix[PietColor](width, height)
  for x in 0..<width:
    for y in 0..<height:
      result[x, y] = rand(maxColorNumber).PietColor


proc printMemories*() =
  proc printMem(mem: int, spec: string) =
    echo spec, " MEM:", mem div 1024 div 1024, "MB"
  getTotalMem().printMem("TOTAL")
  getOccupiedMem().printMem("OCCUP")
  getFreeMem().printMem("FREE ")

proc makeLocalRandomPietColorMatrix*(width, height: int): Matrix[PietColor] =
  randomize()
  result = newMatrix[PietColor](width, height)
  const same = 5
  for x in 0..<width:
    for y in 0..<height:
      result[x, y] = rand(maxColorNumber).PietColor
      if rand(1) == 0:
        if rand(10) > same and x > 0:
          result[x, y] = result[x-1, y]
        if rand(10) > same and y > 0:
          result[x, y] = result[x, y-1]
      else:
        if rand(10) > same and y > 0:
          result[x, y] = result[x, y-1]
        if rand(10) > same and x > 0:
          result[x, y] = result[x-1, y]
