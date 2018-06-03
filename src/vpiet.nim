import sequtils,strutils,algorithm,math,future,macros,strformat
import os,times,terminal,termios,os,posix,random
import nimPNG
import curse
import util, pietmap, indexto, pietorder, pietcore

# make graph
# show index

type
  VPietState = enum Normal
  Rect = tuple[l,t,r,b:int]
  VPiet = ref object
    state:VPietState
    filename:string
    colorMap:Matrix[PietColor]
    pos:tuple[x,y:int]
    scroll:tuple[x,y:int]
    term:tuple[w,h:int]
    log:string
    pMap:PietMap
    core:PietCore

proc `iw`(self:VPiet):int = self.colorMap.width
proc `ih`(self:VPiet):int = self.colorMap.height

proc reAnalyze(self:var VPiet) =
  self.pMap = self.colorMap.newPietMap()
  self.core = self.pMap.newIndexTo().newPietCore()

proc newVPiet(filename:string) :VPiet=
  new(result)
  result.colorMap = loadPNG32(filename).toColorMap()
  result.filename = filename
  result.state = Normal
  result.pos = (0,0)
  result.scroll = (0,0)
  result.term = terminalSize()
  result.log = ""
  result.reAnalyze()

proc drawImage(self:var VPiet,box:Rect) =
  template updateScroll() =
    if self.pos.y + 1 >= box.b + self.scroll.y: self.scroll.y += 1
    if self.pos.y + 1 <  box.t + self.scroll.y: self.scroll.y -= 1
    if self.pos.x + 1 >= box.r + self.scroll.x: self.scroll.x += 1
    if self.pos.x + 1 <  box.l + self.scroll.x: self.scroll.x -= 1
  updateScroll()
  const trans = (c:uint8) => (c.int * 6) div 256
  proc toRealPos(self:var VPiet,x,y:int):tuple[x,y:int] =
    return (x + self.scroll.x,y + self.scroll.y)
  proc getIndex(self:var VPiet,x,y:int): int =
    let (x2,y2) = self.toRealPos(x,y)
    return self.pMap.indexMap[x2,y2]

  let (vx,vy) = (self.pos.x - self.scroll.x, self.pos.y - self.scroll.y)
  let vIndex = self.getIndex(vx,vy)
  self.log &= fmt"i:{vIndex} x:{vx} y:{vy} 0:{self.pMap.indexMap[0,0]}"

  proc drawXY(self:var VPiet,x,y:int,currentColor: var string) : string =
    result = ""
    let (x2,y2) = self.toRealPos(x,y)
    let (r,g,b) = self.colorMap[x2,y2].toRGB()
    let index = self.getIndex(x,y)
    let color = getColor6(trans(r),trans(g),trans(b)).toBackColor()
    if color != currentColor :
      currentColor = color
      result &= "{color}".fmt
    if (x,y) == (vx,vy) : return result & "@"
    for epxy in self.pMap.indexToEndPos[vIndex]:
      let (epx,epy) = epxy
      if (epx.int,epy.int) != (x2,y2): continue
      return result & "*"
    if index == vIndex : return result & "."
    return result & " "
  var currentColor = ""
  for y in 0..< min(self.ih,box.b - box.t):
    currentColor = ""
    setCursorPos(box.l,box.t + y)
    stdout.write getGray24(12).toForeColor()
    for x in 0..< min(self.iw,box.r - box.l):
      stdout.write self.drawXY(x,y,currentColor)
  stdout.write "{endAll}".fmt

proc drawLabel(self: var VPiet,drawYPos:int) =
  let defaultBackColor = getGray24(6).toBackColor()
  block: # write default backcolor
    setCursorPos(0,drawYPos)
    let content = " " * self.term.w
    stdout.write "{defaultBackColor}{content}".fmt
  setCursorPos(0,drawYPos)
  var label = ""
  case self.state:
    of Normal: # print "NORMAL"
      let back = getColor6(0,4,1).toBackColor()
      let fore = getColor6(0,2,0).toForeColor()
      label &= "{back}{fore}{toBold} NORMAL {endAll}".fmt
  block: # print filename
    let fore = getGray24(18).toForeColor()
    let rightContent = fmt "x:{self.pos.x} y:{self.pos.y} w:{self.iw} h:{self.ih}"
    let content = self.filename & "\t | " & rightContent
    label &= "{defaultBackColor}{fore} {content}".fmt
  label &= endAll
  stdout.write label

proc drawLog(self:var VPiet,drawYPos:int) =
  setCursorPos(0,drawYPos)
  terminal.eraseLine()
  if self.log.len >= self.term.w-1: self.log = self.log[..(self.term.w-1)]
  stdout.write self.log


proc update(self:var VPiet,keys:seq[char]) : tuple[waitNext:bool]=
  result = (waitNext:true)
  self.term = terminalSize()
  self.log = ""
  if keys.len < 3:
    let key = keys[0]
    case key:
      of 'k': self.pos.y -= 1
      of 'h': self.pos.x -= 1
      of 'j': self.pos.y += 1
      of 'l': self.pos.x += 1
      else: discard
  elif keys.len >= 3:
    let keyseq = keys[..2]
    if   keyseq == @['\e','[','C']: self.pos.x += 1
    elif keyseq == @['\e','[','D']: self.pos.x -= 1
    elif keyseq == @['\e','[','B']: self.pos.y += 1
    elif keyseq == @['\e','[','A']: self.pos.y -= 1
  self.pos.x = self.pos.x.max(0).min(self.iw-1)
  self.pos.y = self.pos.y.max(0).min(self.ih-1)

proc updateTerminal(self:var VPiet, curse:var Curse) =
  # update する
  curse.isWait = self.update(curse.keys).waitNext
  # draw していく
  # 左上から更新点のみ更新するのが一番きれい
  # eraseScreen()
  self.drawImage((1,1,self.term.w,self.term.h-1))
  self.drawLabel(self.term.h - 1)
  self.drawLog(self.term.h)

proc exitWithHelp(errorLog:string = "") =
  echo """
  {getColor6(1,4,2).toForeColor()}### vpiet : veaaa Piet ###{endAll}
  {toDim}edit png like vi{endAll}
    $ vpiet {getGray24(16).toForeColor()}<filename>{endAll}
  {toDim}execute png as Piet{endAll}
    $ vpiet {toBold}-e{endAll} {getGray24(16).toForeColor()}<filename>{endAll}
  """.fmt().replace("\n  ","\n").strip()
  if errorLog.len > 0:
    echo "{getColor6(5,1,1).toForeColor()}Error : {errorLog}{endAll}".fmt
    quit(errorcode = 1)
  quit()

if isMainModule:
  let params = os.commandLineParams()
  if params.len() == 0: exitWithHelp()
  let files = params.filterIt(not it.startswith("-"))
  if "-h" in params: exitWithHelp()
  if files.len() == 0 : exitWithHelp("No Input File !!")
  if files.len() > 1 : exitWithHelp("Multiple Input Files !!")
  if not files[0].endsWith(".png"): exitWithHelp("Illegal File Type")
  if "-e" in params: # VPietは起動せずにPietを実行
    var core = files[0].newPietMap().newIndexTo().newPietCore()
    core.exec()
  else:
    var vpiet = newVPiet(files[0])
    var curse = newCurse()
    curse.loop :
      vpiet.updateTerminal(curse)