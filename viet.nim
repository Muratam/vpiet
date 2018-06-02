import sequtils,strutils,algorithm,math,future,macros,strformat
import os,times,terminal,termios,os,posix,random
import nimPNG
import pietmap
import util
import curse
import pietcore

type
  VietState = enum Normal
  Rect = tuple[l,t,r,b:int]
  Viet = ref object
    state:VietState
    filename:string
    colorMap:Matrix[PietColor]
    pos:tuple[x,y:int]
    term:tuple[w,h:int]
    log:string
    core:PietCore

proc `iw`(self:Viet):int = self.colorMap.width
proc `ih`(self:Viet):int = self.colorMap.height

proc newViet(filename:string) :Viet=
  new(result)
  result.colorMap = loadPNG32(filename).toColorMap()
  result.filename = filename
  result.state = Normal
  result.pos = (0,0)
  result.term = terminalSize()
  result.log = ""
  result.core = newPietCore(result.colorMap.newPietMap())

proc drawImage(self:var Viet,box:Rect) =
  # WARN: 前の描画結果を利用して高速化可能?
  # let trans = (c:int) => (if c < 100: 0 elif c < 220: 2 else: 5)
  let trans = (c:uint8) => (c.int * 6) div 256
  for y in 0..< min(self.ih,box.b - box.t):
    var currentColor = ""
    setCursorPos(box.l,box.t + y)
    stdout.write toForeColor(getGray24(12))
    for x in 0..< min(self.iw,box.r - box.l):
      let (x2,y2) = (x + self.pos.x,y + self.pos.y)
      let (r,g,b) = self.colorMap[x2,y2].toRGB()
      let color = toBackColor(getColor6(trans(r),trans(g),trans(b)))
      if color != currentColor :
        currentColor = color
        stdout.write "{color}".fmt
      stdout.write " ".fmt
  stdout.write "{endAll}".fmt

proc drawLabel(self: var Viet,drawYPos:int) =
  let defaultBackColor = toBackColor(getGray24(6))
  block: # write default backcolor
    setCursorPos(0,drawYPos)
    let content = " " * self.term.w
    stdout.write "{defaultBackColor}{content}".fmt
  setCursorPos(0,drawYPos)
  var label = ""
  case self.state:
    of Normal: # print "NORMAL"
      let back = toBackColor(getColor6(0,4,1))
      let fore = toForeColor(getColor6(0,2,0))
      label &= "{back}{fore}{toBold} NORMAL {endAll}".fmt
  block: # print filename
    let fore = toForeColor(getGray24(18))
    let rightContent = fmt "x:{self.pos.x} y:{self.pos.y} w:{self.iw} h:{self.ih}"
    let content = self.filename & "\t | " & rightContent
    label &= "{defaultBackColor}{fore} {content}".fmt
  label &= endAll
  stdout.write label

proc drawLog(self:var Viet,drawYPos:int) =
  setCursorPos(0,drawYPos)
  terminal.eraseLine()
  if self.log.len >= self.term.w-1: self.log = self.log[..(self.term.w-1)]
  stdout.write self.log


proc update(self:var Viet,keys:seq[char]) : tuple[waitNext:bool]=
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
  self.pos.x = self.pos.x.min(self.iw - self.term.w+2).max(0).min(self.iw-1)
  self.pos.y = self.pos.y.min(self.ih - self.term.h+2).max(0).min(self.ih-1)
  # self.log &= " key:[" & keys.mapIt(it.int).join(",") & "] "

proc updateTerminal(self:var Viet, curse:var Curse) =
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
  {getColor6(1,4,2).toForeColor()}### viet : veaaa Piet ###{endAll}
  {toDim}edit png like vi{endAll}
    $ viet {getGray24(16).toForeColor()}<filename>{endAll}
  {toDim}execute png as Piet{endAll}
    $ viet {toBold}-e{endAll} {getGray24(16).toForeColor()}<filename>{endAll}

  -- TODO: EDITABLE LIKE VIM--------------------
  NORMAL: <- ESC or C-c で
    hjkl ←↓↑→ キーで移動
  INSERT: NORMAL から i で
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
  if "-e" in params: # Vietは起動せずにPietを実行
    var core = newPietCore(files[0].newPietMap())
    core.exec()
  else:
    var viet = newViet(files[0])
    var curse = newCurse()
    curse.loop :
      viet.updateTerminal(curse)