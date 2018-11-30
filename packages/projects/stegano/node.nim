{.experimental: "notnil".}
import packages/[common, pietbase, frompiet, curse]
import pasm, steganoutil, blockinfo
import sets, hashes, tables


type
  NodeObject* = object
    val*, x*, y*: int
    mat*: Matrix[BlockInfo]
    dp*: DP
    cc*: CC
    fund*: Stack[int]
  Node* = ref NodeObject not nil
  NodeEnv* = ref object
    img*: Matrix[PietColor]
    orders*: seq[PasmOrder]
    maxFrontierNum*: int
    maxFundLevel*: int
    maxTrackBackOrderLen*: int
    fronts*: seq[seq[seq[Node]]]
    nexts*: seq[seq[BinaryHeap[Node]]]
    stored*: seq[seq[HashSet[Hash]]]
    maxNonNilFrontIndex*: int
    maxFunds*: seq[int]
    completedMin*: int
  Codel* = tuple[x, y: int, color: PietColor]
  Key* = tuple[fund, ord: int]


proc width*(env: NodeEnv): int = env.img.width
proc height*(env: NodeEnv): int = env.img.height
proc get*[T](a: var seq[seq[T]], k: Key): var T = a[k.ord][k.fund]

proc newNode*(val, x, y: int, mat: Matrix[BlockInfo], dp: DP, cc: CC,
    fund: Stack[int]): Node =
  new(result)
  result.val = val
  result.x = x
  result.y = y
  result.mat = mat
  result.dp = dp
  result.cc = cc
  result.fund = fund

template newNodeIt*(node: Node, op: untyped): Node =
  var it {.inject.}: Node
  new(it)
  it.val = node.val
  it.x = node.x
  it.y = node.y
  it.dp = node.dp
  it.cc = node.cc
  op
  if it.mat == nil: it.mat = node.mat.deepCopy()
  if it.fund == nil: it.fund = node.fund.deepCopy()
  it


# val(add distance),mat(update to the color)
proc update*(val: var int, color, baseColor: PietColor) = val += distance(
    color, baseColor)
proc update*(env: NodeEnv, c: Codel, val: var int) = val.update(c.color,
    env.img[c.x, c.y])
proc update*(env: NodeEnv, c: Codel, mat: var Matrix[BlockInfo]): bool =
  proc canUpdateEndPos(e: var EightDirection[UsedInfo], x, y: int): bool =
    # 使用済みのところを更新してしまうと駄目(false)
    result = true
    let newPos = (x.int16, y.int16)
    template update(dir) =
      if dir.used: return false
      dir.pos = newPos
    if y < e.upR.pos.y or y == e.upR.pos.y and x > e.upR.pos.x: e.upR.update()
    if y < e.upL.pos.y or y == e.upL.pos.y and x < e.upL.pos.x: e.upL.update()
    if y > e.downR.pos.y or y == e.downR.pos.y and
        x < e.downR.pos.x: e.downR.update()
    if y > e.downL.pos.y or y == e.downL.pos.y and
        x > e.downL.pos.x: e.downL.update()
    if x < e.leftR.pos.x or x == e.leftR.pos.x and
        y < e.leftR.pos.y: e.leftR.update()
    if x < e.leftL.pos.x or x == e.leftL.pos.x and
        y > e.leftL.pos.y: e.leftL.update()
    if x > e.rightR.pos.x or x == e.rightR.pos.x and
        y > e.rightR.pos.y: e.rightR.update()
    if x > e.rightL.pos.x or x == e.rightL.pos.x and
        y < e.rightL.pos.y: e.rightL.update()
  template syncSameBlocks(blockInfo: BlockInfo) =
    for index in blockInfo.sameBlocks: mat.data[index] = blockInfo
  doAssert mat[c.x, c.y] == nil
  if c.color == WhiteNumber:
    mat[c.x, c.y] = whiteBlockInfo
    return true
  if c.color == BlackNumber:
    mat[c.x, c.y] = blackBlockInfo
    return true
  let adjasts = mat.checkAdjasts(c.x, c.y, c.color)
  if adjasts.len() == 0: # 新規
    mat[c.x, c.y] = env.img.newBlockInfo(c.x, c.y, c.color)
    return true
  for adjast in adjasts: # そもそも全部結合していいやつかチェック
    if adjast.sizeFix: return false
  # とりあえず自身をコピーした0番に結合
  let zeroBlock = adjasts[0].deepCopy()
  zeroBlock.sameBlocks &= env.img.getI(c.x, c.y)
  if not zeroBlock.endPos.canUpdateEndPos(c.x, c.y): return false
  template connect(adjast) = # コピーが作成されているゼロ番に結合
    let newBlock = adjast.deepCopy()
    # チェック
    for b in zeroBlock.sameBlocks:
      let (bx, by) = env.img.getXY(b)
      if not newBlock.endPos.canUpdateEndPos(bx, by): return false
    for b in newBlock.sameBlocks:
      let (bx, by) = env.img.getXY(b)
      if not zeroBlock.endPos.canUpdateEndPos(bx, by): return false
    # 使用済みを共有
    for ccdp in allCCDP():
      let (cc, dp) = ccdp
      let used = zeroBlock.endPos[cc, dp].used or newBlock.endPos[cc,
          dp].used
      zeroBlock.endPos[cc, dp] = (used, zeroBlock.endPos[cc, dp].pos)
    # 更新
    zeroBlock.sameBlocks &= newBlock.sameBlocks
  for l in 1..<adjasts.len(): adjasts[l].connect()
  zeroBlock.syncSameBlocks()
  return true
proc update*(env: NodeEnv, c: Codel, mat: var Matrix[BlockInfo],
    val: var int): bool =
  val.update(c.color, env.img[c.x, c.y])
  return update(env, c, mat)

proc newEnv*(
    img: Matrix[PietColor],
    orders: seq[PasmOrder],
    maxFrontierNum: int = 720,
    maxFundLevel: int = 6,
    maxTrackBackOrderLen: int = 30): NodeEnv =
  proc setupFirstFront(env: NodeEnv) =
    for c in 0..<chromMax:
      var initMat = newMatrix[BlockInfo](env.width, env.height) # 全てnil
      var val = 0
      let state = (0, 0, c.PietColor)
      if not env.update(state, initMat, val): quit("yabee")
      env.fronts[0][0] &= newNode(val, 0, 0, initMat, newDP(), newCC(),
          newStack[int]())
  new(result)
  result.img = img
  result.orders = orders
  result.maxFrontierNum = maxFrontierNum
  result.maxFundLevel = maxFundLevel
  result.maxTrackBackOrderLen = maxTrackBackOrderLen
  result.fronts = newSeqWith(orders.len()+1, newSeqWith(result.maxFundLevel,
      newSeq[Node]()))
  result.setupFirstFront()
  result.completedMin = EPS
  doAssert result.width < int16.high and result.height < int16.high

proc getFront*(env: NodeEnv, ord: int): seq[Node] =
  result = @[]
  for fr in env.fronts[ord]:
    for f in fr:
      result &= f

proc prepare*(env: NodeEnv) =
  env.nexts = newSeqWith(env.orders.len()+1, newSeqWith(env.maxFundLevel,
      newBinaryHeap[Node](proc(x, y: Node): int = y.val - x.val)))
  # top()が一番雑魚
  env.stored = newSeqWith(env.orders.len()+1, newSeqWith(env.maxFundLevel,
      initSet[Hash]()))
  env.maxNonNilFrontIndex = toSeq(0..<env.fronts.len()).filterIt(env.fronts[
      it].mapIt(it.len()).sum() > 0).max()
  env.maxFunds = toSeq(0..<env.maxFundLevel).mapIt(env.maxFrontierNum div (
      1 + 4 * it))

proc getMaxFunds*(env: NodeEnv, k: Key): int =
  let trackbacked =
    (k.ord - env.maxNonNilFrontIndex + env.maxTrackBackOrderLen).float /
      env.maxTrackBackOrderLen.float
  return int(env.maxFunds[k.fund].float * max(1.0, trackbacked))

# 命令を実行できる人の方が偉いので強い重みをつける()
proc getStoredWorstVal*(env: NodeEnv, k: Key): int =
  if k.fund >= env.maxFundLevel: return -1 # 越えたときも-1で簡易的に弾く
  if env.nexts.get(k).len() < env.getMaxFunds(k): return min(EPS,
      env.completedMin)
  if env.nexts.get(k).len() == 0: return min(EPS, env.completedMin)
  return min(env.nexts.get(k).top().val, env.completedMin)

proc setupNextFronts*(env: NodeEnv) =
  let nextItems = (proc(): seq[seq[seq[Node]]] =
    result = newSeqWith(env.orders.len()+1, newSeqWith(env.maxFundLevel,
        newSeq[Node]()))
    for i in 0..<env.nexts.len():
      var next = env.nexts[i]
      for j in 0..<next.len():
        result[i][j] &= env.nexts[i][j].items()
    )()
  env.fronts = nextItems.mapIt(it.mapIt(it.sorted((a, b)=>a.val-b.val)))

proc checkIterateResult*(env: NodeEnv): bool =
  result = true
  let maxes = env.fronts.mapIt(it.mapIt(it.len()).sum())
  for i in 0..<env.fronts.len():
    let front = env.fronts[^(1+i)]
    if front.len() == 0: continue
    if front[0].len() == 0: continue
    # 最後のプロセス省略
    for j in 0..<1.min(front[0].len()):
      # echo fronts.mapIt(it.mapIt(it.len()))
      # echo stored.mapIt(it.mapIt(it.card).sum())
      # echo nextItems.mapIt(it.mapIt(it.len()))
      # echo nextItems.mapIt(it.mapIt(it.mapIt(it.val)).filterIt(it.len() > 0).mapIt([it.max(),it.min()]))
      # echo front[0].mat.newGraph().mapIt(it.orderAndSizes.mapIt(it.pasmType))
      # stdout.write progress;stdout.flushFile
      echo maxes
      echo front[0][j].mat.toConsole(), front[0][0].val, "\n"
      # echo front[0][j].mat.toPietColorMap().newGraph().mapIt(it.orderAndSizes.mapIt(it.pasmType))
      echo "memory  :", getTotalMem() div 1024 div 1024, "MB"
    break
  if maxes[^1] > 0 and maxes[^2] == 0 and maxes[^3] == 0:
    return false

proc getResult*(env: NodeEnv): Matrix[PietColor] =
  var front = env.fronts[^1][0]
  proc embedNotdecided(f: var Node) =
    let initMat = f.mat.deepCopy()
    for x in 0..<f.mat.width:
      for y in 0..<f.mat.height:
        if f.mat[x, y] != nil: continue
        let color = env.img[x, y]
        let adjast = (proc(f: var Node): bool =
          for dxdy in dxdys:
            let (dx, dy) = dxdy
            let (nx, ny) = (x+dx, y+dy)
            if not env.img.isIn(nx, ny): continue
            if initMat[nx, ny] == nil: continue
            if initMat[nx, ny].color == color: return true
          return false
        )(f)
        if color < chromMax and adjast: continue
        if not env.update((x, y, color), f.mat, f.val): quit("yabeeyo")
    # 隣接しているので一番近い色を埋める
    for x in 0..<f.mat.width:
      for y in 0..<f.mat.height:
        if f.mat[x, y] != nil: continue
        let color = env.img[x, y]
        var newMat = f.mat.deepCopy()
        var newVal = f.val
        if env.update((x, y, color), newMat, newVal):
          f.mat = newMat
          f.val = newVal
          continue
        type Try = tuple[success: bool, mat: Matrix[BlockInfo], val: int]
        var tries = newSeq[Try]()
        for c in 0..<chromMax:
          var success = false
          var newMat = f.mat.deepCopy()
          var newVal = f.val
          if env.update((x, y, c.PietColor), newMat, newVal):
            success = true
          tries &= (success, newMat, newVal)
        tries = tries.filterIt(it.success).sorted((a, b) => a.val - b.val)
        f.mat = tries[0].mat
        f.val = tries[0].val
  proc findEmbeddedMinIndex(): int =
    var minIndex = 0
    var minVal = EPS
    for i, f in front:
      front[i].embedNotdecided()
      if minVal < front[i].val: continue
      minIndex = i
      minVal = front[i].val
    return minIndex


  doAssert front.len() > 0
  let mats = front.mapIt(it.mat.deepCopy())
  let index = findEmbeddedMinIndex()
  result = front[index].mat.toPietColorMap()
  echo "result: before\n", mats[index].toPietColorMap().toConsole()
  echo "result :\n", result.toConsole(), front[index].val
  echo "base   :\n", env.img.toConsole()
  echo mats[index].toPietColorMap().newGraph().mapIt(it.orderAndSizes.mapIt(
      it.order))
  echo result.newGraph().mapIt(it.orderAndSizes.mapIt(it.order))
  echo env.orders
