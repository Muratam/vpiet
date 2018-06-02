import sequtils,strutils,algorithm,math,future,macros,strformat
import nimPNG
import os
import random
import pietcore

proc makeGraph(filename:string) =
  let core = newPietCore(filename)
  echo core.filename
  var dot = """digraph pietgraph {
    graph [ charset = "UTF-8", fontname = "Menlo", style = "filled" ];
    node [ shape = square, fontname = "Menlo", style = "filled",
        fontcolor = "#222222", fillcolor = "#ffffff", ];"""
  # for i in 0..<maxIndex:
  #   for _ in 0..<4:
  #     if rand(1.0) > 0.1 : continue
  #     let r = rand(maxIndex)
  #     if r == i : continue
  #     dot &= fmt"""a{i} [label = "a{i}",fontcolor = "#222222",fillcolor = "#ffffff"];"""
  #     dot &= fmt"""a{i} -> a{r} [label = "➜"];"""
  dot &= "}"
  echo dot

let params = os.commandLineParams()
if params.len() == 0:
  echo "no params"
  quit()
for filename in params:
  makeGraph(filename)