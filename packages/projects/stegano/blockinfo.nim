import packages/[common, pietbase, frompiet, curse]
import steganoutil
import sets, hashes, tables
import options

type
  Pos* = tuple[x, y: int16] # 25:390MB -> 25:268MB # メモリが 2/3で済む(int8ではほぼ変化なし)
  # マスを増やすという操作のために今のブロックの位置配列を持っておく
  UsedInfo* = tuple[used: bool, pos: Pos]
  Cursor* = tuple[x, y: int, dp: DP, cc: CC]

  BlockInfoObject* = object
    # 有彩色以外では color以外の情報は参考にならないことに注意
    # -> deepcopy時に白や黒はサボれる
    endPos*: EightDirection[UsedInfo]
    color*: PietColor
    sameBlocks*: seq[int] # ブロックサイズはここから取得できる
    sizeFix*: bool # Pushしたのでこのサイズでなくてはならないというフラグ
  BlockInfo* = ref BlockInfoObject

proc `[]`*[T](self: Matrix[T], cursor: Cursor): T =
  self[cursor.x, cursor.y]
proc `[]`*[T](self: EightDirection[T], cursor: Cursor): T =
  self[cursor.cc, cursor.dp]
proc `[]=`*[T](self: EightDirection[T], cursor: Cursor, val: T) =
  self[cursor.cc, cursor.dp] = T
proc getEndPos*(self: Matrix[BlockInfo], cursor: Cursor): UsedInfo =
  self[cursor].endPos[cursor.cc, cursor.dp]

proc newBlockInfo*(base: Matrix[PietColor], x, y: int,
    color: PietColor): BlockInfo =
  # 新たに(隣接のない前提で)1マス追記
  new(result)
  let index = if base != nil: base.getI(x, y) else: -1
  result.endPos = newEightDirection((false, (x.int16, y.int16)))
  result.color = color
  result.sameBlocks = @[index]
  result.sizeFix = false

let whiteBlockInfo* = newBlockInfo(nil, -1, -1, WhiteNumber)
let blackBlockInfo* = newBlockInfo(nil, -1, -1, BlackNumber)

proc hashing*(mat: Matrix[BlockInfo]): Hash =
  const nilhash = hash(-1)
  # 速度のために正確さを犠牲にしたらこうなるが...
  # for d in mat.data:
  #   result += result shl 5 + (if d == nil: nilhash else: hash(d.color))
  for d in mat.data:
    result = result !& (if d == nil: nilhash else: hash(d.color))
  result = !$result

proc skipHashing*(mat: Matrix[BlockInfo], interval: int = 4): Hash =
  const nilhash = hash(-1)
  var i = 0
  while i < mat.data.len():
    let d = mat.data[i]
    result += result shl 5 + (if d == nil: nilhash else: hash(d.color))
    i += interval

proc deepCopy*(x: BlockInfo): BlockInfo =
  # コピーコンストラクタはおそすぎるので直代入
  new(result)
  # result[] = x[]
  result.endPos = x.endPos
  result.color = x.color
  result.sameBlocks = x.sameBlocks
  result.sizeFix = x.sizeFix

proc toConsole*(self: Matrix[BlockInfo]): string =
  var mat = newMatrix[PietColor](self.width, self.height)
  for x in 0..<self.width:
    for y in 0..<self.height:
      mat[x, y] = if self[x, y] == nil: -1 else: self[x, y].color
  return mat.toConsole()

proc toPietColorMap*(self: Matrix[BlockInfo]): Matrix[PietColor] =
  result = newMatrix[PietColor](self.width, self.height)
  for x in 0..<self.width:
    for y in 0..<self.height:
      if self[x, y] == nil: result[x, y] = -1
      else: result[x, y] = self[x, y].color


proc checkAdjasts*(mat: Matrix[BlockInfo], x, y: int, color: PietColor): seq[BlockInfo] =
  # color と同じ色で隣接しているものを取得
  result = @[]
  for dxdy in dxdys:
    let (dx, dy) = dxdy
    let (nx, ny) = (x + dx, y + dy)
    if not mat.isIn(nx, ny): continue
    if mat[nx, ny] == nil: continue
    if mat[nx, ny].color != color: continue
    if mat[nx, ny] in result: continue # 大丈夫...?
    result &= mat[nx, ny]
type IntPos* = tuple[x, y: int]
proc getNextPos*(endPos: EightDirection[UsedInfo], dp: DP, cc: CC): IntPos =
  let (x, y) = endPos[cc, dp].pos
  let (dX, dY) = dp.getdXdY()
  return (x + dX, y + dY)

proc currentNextPos*(mat: Matrix[BlockInfo], cursor: Cursor): IntPos =
  mat[cursor].endPos.getNextPos(cursor.dp, cursor.cc)
# 次に行ったことのない壁ではない場所を探索
proc searchNotVisited*(mat: Matrix[BlockInfo], startCursor: Cursor): Option[Cursor] =
  var cursor = startCursor
  assert mat[cursor] != nil and mat[cursor].color < chromMax
  for i in 0..<8:
    let used = mat.getEndPos(cursor).used
    let (nX, nY) = mat[cursor].endPos.getNextPos(cursor.dp, cursor.cc)
    if not mat.isIn(nX, nY) or (mat[nX, nY] != nil and mat[nX, nY].color == BlackNumber):
      if i mod 2 == 0: cursor.cc.toggle()
      else: cursor.dp.toggle(1)
      continue
    if used: return none(Cursor)
    cursor.x = nX
    cursor.y = nY
    return some(cursor)
  return none(Cursor)

# 現在のカーソル方向を使用済みに全て更新し,返却
proc markCurrentAndGetNextPos*(mat: var Matrix[BlockInfo], cursor: Cursor): IntPos =
  if not mat.getEndPos(cursor).used:
    let newBlock = mat[cursor].deepCopy()
    newBlock.endPos[cursor.cc, cursor.dp] = (true, newBlock.endPos[cursor.cc, cursor.dp].pos)
    for b in newBlock.sameBlocks: mat.data[b] = newBlock
  return mat.currentNextPos(cursor)

# 使用したことのない場所で新たに行けるならそれを返却
proc toNextStateAndGetNextCursor*(mat: var Matrix[BlockInfo],startCursor: Cursor): Option[Cursor] =
  var cursor = startCursor
  assert mat[cursor] != nil and mat[cursor].color < chromMax
  var usedDir: EightDirection[bool]
  for i in 0..<8:
    let used = mat.getEndPos(cursor).used
    let (nX, nY) = mat.currentNextPos(cursor)
    usedDir[cursor.cc, cursor.dp] = true
    if not mat.isIn(nX, nY) or (mat[nX, nY] != nil and mat[nX, nY].color == BlackNumber):
      if i mod 2 == 0: cursor.cc.toggle()
      else: cursor.dp.toggle(1)
      continue
    if used: return none(Cursor)
    let newBlock = mat[cursor].deepCopy()
    for ccdp in allCCDP():
      let (ncc, ndp) = ccdp
      if not usedDir[ncc, ndp]: continue
      newBlock.endPos[ncc, ndp] = (true, newBlock.endPos[ncc, ndp].pos)
    for b in newBlock.sameBlocks: mat.data[b] = newBlock
    cursor.x = nX
    cursor.y = nY
    return some(cursor)
  return none(Cursor)
