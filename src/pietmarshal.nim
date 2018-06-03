
import sequtils,strutils,algorithm,math,future,macros,strformat
import os,times
import pietmap
import util
import strscans
import streams
import pietMap
import pietCore

# 0.3s at htmlserver.png
# (C lang interface ?)

proc loadPietCore*(filename:string) : PietCore =
  let s = newFileStream(filename,fmRead)
  let maxIndex = s.readLine().parseInt()
  var to : IndexTo
  to.new()
  to.blockSize = newSeq[int](maxIndex)
  to.nextEdges = newSeq[NextDirectedEdges](maxIndex)
  for i in 0..< maxIndex:
    to.blockSize[i] = s.readLine().parseInt()
  for i in 0..< maxIndex:
    let args = s.readLine().split(",") # fscanf ?
    template readEdge(num:int):untyped =
      to.nextEdges[i][num].order = args[0][num].fromChar()
      to.nextEdges[i][num].index = args[1 + num].parseInt()
    readEdge(0)
    readEdge(1)
    readEdge(2)
    readEdge(3)
    readEdge(4)
    readEdge(5)
    readEdge(6)
    readEdge(7)
  return to.newPietCore()

proc store*(core:PietCore,filename:string) =
  let s = newFileStream(filename,fmWrite)
  let to = core.indexTo
  let maxIndex = to.blockSize.len()
  s.writeLine maxIndex
  for i in 0..< maxIndex:
    s.writeLine to.blockSize[i]
  for i in 0..< maxIndex:
    for e in to.nextEdges[i]:
      s.write e.order.toChar()
    for e in to.nextEdges[i]:
      s.write "{e.index},".fmt()
    s.write "\n"
