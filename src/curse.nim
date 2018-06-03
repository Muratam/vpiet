import sequtils,strutils,algorithm,math,future,macros,strformat
import os,times
import random
import terminal,termios,os,posix
from libs.ncurses.ncurses as nc import nil
proc timeout(t:int): void {.cdecl, discardable, importc: "timeout", dynlib: nc.libncurses.}

proc code*[T](key:T) : string = fmt "\e[{key}m"
proc toForeColor*(i:int): string = code( fmt"38;5;{i}" )
proc toBackColor*(i:int): string = code( fmt"48;5;{i}" )
proc getColor6*(r,g,b:range[0..6]) : int = 16 + 36 * r + 6 * g + b # all in  0 to 6
proc getGray24*(gray:range[0..24]):int = 232 + gray # in 0 to 24
let
  toBold* = code(1)
  toDim* = code(2)
  toUnderline* = code(4)
  toBlink* = code(5) #  6 : rapid
  endAll* = code(0)
  endBold* = code(21)
  endDim* = code(22)
  endUnderline* = code(24)
  endBlink* = code(25)
  toForeDefault* = code(39)
  toForeBlack* = code(30) # ...
  toForeLightGray* = code(37)
  toForeDarkGray* = code(90) # ...
  toForeWhite* = code(97)
  toBackDefault* = code(49)
  toBackRed* = code(40) # ...
  toBackLightGray* = code(47)
  toBackDarkGray* = code(100) # ...
  toBackWhite* = code(107)
proc colorTest()=
  for i in 0..<256:
    # https://en.wikipedia.org/wiki/ANSI_escape_code
    stdout.write fmt "{toForeColor(i)}{toDim}{toBold}{i}{endAll} "

type Curse* = ref object
  isWait* : bool
  exitKeys: seq[char]
  keys*: seq[char]

proc newCurse*(exitKeys = @['q'],isWait = false):Curse =
  new(result)
  result.isWait = isWait
  result.exitKeys = exitKeys
  result.keys = @[]
  # setup
  nc.initscr()
  nc.noecho()
  nc.raw()
  hideCursor()

proc close(curse:var Curse) =
  showCursor()
  nc.endwin()

proc getKeys*(curse:var Curse) :seq[char] =
  result = @[]
  timeout(if curse.isWait : -1  else : 16)
  let key = nc.getch().char
  if key.int == 255: return @[]
  result &= key
  for i in 0..10:
    timeout(5)
    let key = nc.getch().char
    if key.int == 255: break
    result &= key

proc draw(curse:var Curse) =
  setCursorPos(0,0)
  let (w,h) = terminalSize()
  eraseScreen()
  colorTest()
  let key = if curse.keys.len > 0 : curse.keys[0] else: ' '
  for y in 0..<(h div 2):
    for x in 0..<(w div 2):
      stdout.write fmt "{key}"
    if y != h - 1: stdout.write "\r\n"

template loop*(curse:var Curse,updateFun:typed) =
  while true:
    let keys = curse.getKeys()
    if keys.anyIt(it in curse.exitKeys) : break
    curse.keys = keys
    try: updateFun
    except Exception:
      curse.close()
      raise getCurrentException()
    stdout.flushFile()
  curse.close()

if isMainModule:
  var curse = newCurse()
  curse.loop:
    curse.draw()
