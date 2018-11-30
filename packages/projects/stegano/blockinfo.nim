import packages/[common, pietbase, frompiet, curse]
import pasm, steganoutil
import sets, hashes, tables


type
  Pos* = tuple[x, y: int16] # 25:390MB -> 25:268MB # メモリが 2/3で済む(int8ではほぼ変化なし)
  # マスを増やすという操作のために今のブロックの位置配列を持っておく
  UsedInfo* = tuple[used: bool, pos: Pos]

  BlockInfoObject* = object
    # 有彩色以外では color以外の情報は参考にならないことに注意
    # -> deepcopy時に白や黒はサボれる
    endPos*: EightDirection[UsedInfo]
    color*: PietColor
    sameBlocks*: seq[int] # ブロックサイズはここから取得できる
    sizeFix*: bool # Pushしたのでこのサイズでなくてはならないというフラグ
  BlockInfo* = ref BlockInfoObject



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
  for d in mat.data:
    result = result !& hash(if d == nil: -1 else: d.color)
  result = !$result

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


proc checkAdjasts*(mat: Matrix[BlockInfo], x, y: int, color: PietColor): seq[
    BlockInfo] =
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

proc getNextPos*(endPos: EightDirection[UsedInfo], dp: DP, cc: CC): tuple[x,
    y: int] =
  let (x, y) = endPos[cc, dp].pos
  let (dX, dY) = dp.getdXdY()
  return (x + dX, y + dY)
proc searchNotVisited*(mat: Matrix[BlockInfo], x, y: int, startDP: DP,
    startCC: CC): tuple[ok: bool, dp: DP, cc: CC] =
  # 次に行ったことのない壁ではない場所にいけるかどうかだけチェック(更新はしない)
  doAssert mat[x, y] != nil and mat[x, y].color < chromMax
  var dp = startDP
  var cc = startCC
  result = (false, dp, cc)
  for i in 0..<8:
    let used = mat[x, y].endPos[cc, dp].used
    let (nX, nY) = mat[x, y].endPos.getNextPos(dp, cc)
    if not mat.isIn(nX, nY) or (mat[nX, nY] != nil and mat[nX,
        nY].color == BlackNumber):
      if i mod 2 == 0: cc.toggle()
      else: dp.toggle(1)
      continue
    if used: return
    return (true, dp, cc)
  return
proc updateUsingNextPos*(mat: var Matrix[BlockInfo], x, y: int, dp: DP,
    cc: CC): tuple[x, y: int] =
  # 使用済みに変更して全部更新してから返却
  if not mat[x, y].endPos[cc, dp].used:
    let newBlock = mat[x, y].deepCopy()
    newBlock.endPos[cc, dp] = (true, newBlock.endPos[cc, dp].pos)
    for b in newBlock.sameBlocks: mat.data[b] = newBlock
  return mat[x, y].endPos.getNextPos(dp, cc)
proc toNextState*(mat: var Matrix[BlockInfo], x, y: int, startDP: DP,
    startCC: CC): tuple[ok: bool, x, y: int, dp: DP, cc: CC] =
  # 使用したことのない場所で新たに行けるならそれを返却
  doAssert mat[x, y] != nil and mat[x, y].color < chromMax
  template failed(): untyped = (false, x, y, startDP, startCC)
  var dp = startDP
  var cc = startCC
  var usedDir: EightDirection[bool]
  for i in 0..<8:
    let used = mat[x, y].endPos[cc, dp].used
    let (nX, nY) = mat[x, y].endPos.getNextPos(dp, cc)
    usedDir[cc, dp] = true
    if not mat.isIn(nX, nY) or (mat[nX, nY] != nil and mat[nX,
        nY].color == BlackNumber):
      if i mod 2 == 0: cc.toggle()
      else: dp.toggle(1)
      continue
    if used: return failed
    let newBlock = mat[x, y].deepCopy()
    for ccdp in allCCDP():
      let (ncc, ndp) = ccdp
      if not usedDir[ncc, ndp]: continue
      newBlock.endPos[ncc, ndp] = (true, newBlock.endPos[ncc, ndp].pos)
    for b in newBlock.sameBlocks: mat.data[b] = newBlock
    return (true, nX, nY, dp, cc)
  return failed


