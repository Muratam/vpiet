{.experimental: "notnil".}
import packages/[common, pietbase, frompiet, curse]
import pasm, steganoutil, blockinfo
import sets, hashes, tables
# import nimprof

type
  NodeObject = object
    val, x, y: int
    mat: Matrix[BlockInfo]
    dp: DP
    cc: CC
    fund: Stack[int]
  Node = ref NodeObject not nil
  NodeEnv = ref object
    img: Matrix[PietColor]
    orders: seq[PasmOrder]
    maxFrontierNum: int
    maxFundLevel: int
    maxTrackBackOrderLen: int
    fronts: seq[seq[seq[Node]]]
    nexts: seq[seq[BinaryHeap[Node]]]
    stored: seq[seq[HashSet[Hash]]]
    maxNonNilFrontIndex: int
    maxFunds: seq[int]
    completedMin: int
  Codel = tuple[x, y: int, color: PietColor]
  Key = tuple[fund, ord: int] # WARN: 逆として処理しているものがあるかも


proc width(env: NodeEnv): int = env.img.width
proc height(env: NodeEnv): int = env.img.height
proc get[T](a: var seq[seq[T]], k: Key): var T = a[k.ord][k.fund]

proc newNode(val, x, y: int, mat: Matrix[BlockInfo], dp: DP, cc: CC,
    fund: Stack[int]): Node =
  new(result)
  result.val = val
  result.x = x
  result.y = y
  result.mat = mat
  result.dp = dp
  result.cc = cc
  result.fund = fund

template newNodeIt(node: Node, op: untyped): Node =
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
proc update(val: var int, color, baseColor: PietColor) = val += distance(
    color, baseColor)
proc update(env: NodeEnv, c: Codel, val: var int) = val.update(c.color,
    env.img[c.x, c.y])
proc update(env: NodeEnv, c: Codel, mat: var Matrix[BlockInfo]): bool =
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
proc update(env: NodeEnv, c: Codel, mat: var Matrix[BlockInfo],
    val: var int): bool =
  val.update(c.color, env.img[c.x, c.y])
  return update(env, c, mat)

proc newEnv(img: Matrix[PietColor], orders: seq[PasmOrder]): NodeEnv =
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
  result.maxFrontierNum = 720 #720
  result.maxFundLevel = 6     #6
  result.maxTrackBackOrderLen = 30
  result.fronts = newSeqWith(orders.len()+1, newSeqWith(result.maxFundLevel,
      newSeq[Node]()))
  result.setupFirstFront()
  result.completedMin = EPS
  doAssert result.width < int16.high and result.height < int16.high

proc getFront(env: NodeEnv, ord: int): seq[Node] =
  result = @[]
  for fr in env.fronts[ord]:
    for f in fr:
      result &= f

proc prepare(env: NodeEnv) =
  env.nexts = newSeqWith(env.orders.len()+1, newSeqWith(env.maxFundLevel,
      newBinaryHeap[Node](proc(x, y: Node): int = y.val - x.val)))
  # top()が一番雑魚
  env.stored = newSeqWith(env.orders.len()+1, newSeqWith(env.maxFundLevel,
      initSet[Hash]()))
  env.maxNonNilFrontIndex = toSeq(0..<env.fronts.len()).filterIt(env.fronts[
      it].mapIt(it.len()).sum() > 0).max()
  env.maxFunds = toSeq(0..<env.maxFundLevel).mapIt(env.maxFrontierNum div (
      1 + 4 * it))

proc getMaxFunds(env: NodeEnv, k: Key): int =
  let trackbacked =
    (k.ord - env.maxNonNilFrontIndex + env.maxTrackBackOrderLen).float /
      env.maxTrackBackOrderLen.float
  return int(env.maxFunds[k.fund].float * max(1.0, trackbacked))

# 命令を実行できる人の方が偉いので強い重みをつける()
proc getStoredWorstVal(env: NodeEnv, k: Key): int =
  if k.fund >= env.maxFundLevel: return -1 # 越えたときも-1で簡易的に弾く
  if env.nexts.get(k).len() < env.getMaxFunds(k): return min(EPS,
      env.completedMin)
  if env.nexts.get(k).len() == 0: return min(EPS, env.completedMin)
  return min(env.nexts.get(k).top().val, env.completedMin)


type Target = tuple[env: NodeEnv, node: Node, ord: int]
proc searchNotVisited(node: Node): NotVisited = searchNotVisited(node.mat,
    node.x, node.y, node.dp, node.cc)
proc currentBlock(node: Node): BlockInfo = node.mat[node.x, node.y]
proc currentEndPos(node: Node): EightDirection[UsedInfo] = node.currentBlock(
    ).endPos
proc nextKey(t: Target, d: Key): Key = (t.node.fund.len() + d.fund,
    t.ord + d.ord)
proc currentOrder(t: Target): PasmOrder = t.env.orders[t.ord]
proc toNextState(mat: var Matrix[BlockInfo],
  node: Node): NextStateResult = mat.toNextState(node.x, node.y, node.dp,
    node.cc)

proc tryUpdate(t: Target, c: Codel, dKey: Key): tuple[ok: bool, val: int,
    mat: Matrix[BlockInfo]] =
  template mistaken(): untyped = (false, -1, newMatrix[BlockInfo](0, 0))
  block: # 一回試してみる
    var tmpVal = t.node.val
    t.env.update(c, tmpVal)
    if t.env.getStoredWorstVal(t.nextKey(dKey)) <= tmpVal: return mistaken
  var newMat = t.node.mat.deepCopy()
  var newVal = t.node.val
  if not t.env.update(c, newMat, newVal): return mistaken
  return (true, newVal, newMat)

proc tryUpdateNotVisited(t: Target, color: PietColor, dKey: Key,
    onlyNil: bool = false, onlySameColor: bool = false,
    onlyNotUsedCCDP: bool = false): bool =
  # 一回試してみる(+nilなら更新した時のコストもチェック)
  let (ok, dp, cc) = t.node.searchNotVisited()
  if not ok: return false
  let (nx, ny) = t.node.currentEndPos.getNextPos(dp, cc)
  if t.node.mat[nx, ny] == nil:
    var tmpVal = t.node.val
    tmpVal.update(color, t.env.img[nx, ny])
    if t.env.getStoredWorstVal(t.nextKey(dKey)) <= tmpVal: return false
    return true
  # そもそも空いて無いと駄目
  if onlyNil: return false
  # 交差した時だと思うけれども同じ色しか駄目
  if onlySameColor and t.node.mat[nx, ny].color != color: return false
  # 交差した時に,ループに陥らないよう,今のままのdpccで行けるかチェック
  if onlyNotUsedCCDP and t.node.mat[nx, ny].endPos[cc, dp].used: return false
  return true

# 偶然にも全く同じ画像が作られてしまうことがあるので,同じものがないかを確認してhashを取る必要がある
proc store(env: NodeEnv, node: Node, ord: int) =
  let k: Key = (node.fund.len(), ord)
  if k.fund >= env.maxFundLevel: return
  if env.getStoredWorstVal(k) <= node.val: return
  let hashing = node.mat.hashing
  if hashing in env.stored.get(k): return
  env.nexts.get(k).push(node)
  env.stored.get(k).incl(hashing)
  if env.nexts.get(k).len() > env.getMaxFunds(k):
    # exclしなくてもいいかな
    discard env.nexts.get(k).pop()

proc store(t: Target) = store(t.env, t.node, t.ord)

proc checkTerminate(t: Target) =
  var newMat = t.node.mat.deepCopy()
  var dp = t.node.dp
  var cc = t.node.cc
  var newVal = t.node.val
  for i in 0..<8:
    let (nX, nY) = newMat.updateUsingNextPos(t.node.x, t.node.y, dp, cc)
    if t.node.mat.isIn(nX, nY):
      if newMat[nX, nY] == nil:
        if not t.env.update((nX, nY, BlackColor), newMat, newVal): return
      elif newMat[nX, nY].color != BlackNumber: return
    if i mod 2 == 0: cc.toggle()
    else: dp.toggle(1)
  let nextNode = t.node.newNodeIt:
    it.val = newVal
    it.mat = newMat
    it.dp = dp
    it.cc = cc
  t.env.store(nextNode, t.ord+1)

proc extendBlock(t: Target) =
  let here = t.node.currentBlock
  if here.color >= chromMax: return
  for b in here.sameBlocks:
    let (bx, by) = t.node.mat.getXY(b)
    for dxdy in dxdys:
      let (dx, dy) = dxdy
      let (nx, ny) = (bx + dx, by + dy)
      if not t.node.mat.isIn(nx, ny): continue
      let ext = t.node.mat[nx, ny]
      if ext != nil: continue
      let (ok, newVal, newMat) = t.tryUpdate((nx, ny, here.color), (0, 0))
      if not ok: continue
      let nextNode = t.node.newNodeIt:
        it.val = newVal
        it.x = nx
        it.y = ny
        it.mat = newMat
      store(t.env, nextNode, t.ord)
      if t.currentOrder.order == Terminate:
        (t.env, nextNode, t.ord).checkTerminate()

proc decide(t: Target, order: Order, dKey: Key,
    callback: proc(_: var Node): bool = (proc(_: var Node): bool = true)) =
  let here = t.node.currentBlock
  let color = here.color.getNextColor(order).PietColor
  if not t.tryUpdateNotVisited(color, dKey, onlySameColor = true,
      onlyNotUsedCCDP = true): return
  var newMat = t.node.mat.deepCopy()
  let (ok, nx, ny, dp, cc) = newMat.toNextState(t.node)
  if not ok: quit("yabee")
  if newMat[nx, ny] != nil:
    let next = newMat[nx, ny]
    if next.color != color or next.endPos[cc, dp].used: quit("yabee")
    var nextNode = t.node.newNodeIt:
      it.x = nx
      it.y = ny
      it.mat = newMat
      it.dp = dp
      it.cc = cc
    if not nextNode.callback(): return
    store(t.env, nextNode, t.ord+dKey.ord)
    return
  var newVal = t.node.val
  if not t.env.update((nx, ny, color), newMat, newVal): return
  var nextNode = newNode(newVal, nx, ny, newMat, dp, cc, t.node.fund.deepCopy())
  if order == Push: newMat[t.node.x, t.node.y].sizeFix = true
  if not nextNode.callback(): return
  store(t.env, nextNode, t.ord+dKey.ord)

proc processLastOrder(env: NodeEnv, front: seq[Node], ord: int) =
  if ord != env.orders.len(): return
  if front.len() > 0: env.completedMin = front.mapIt(it.val).max() + 1
  for f in front: (env, f, ord).store()
  if front.len() > 0: env.completedMin = front.mapIt(it.val).min()

proc doOrder(t: Target) =
  let here = t.node.currentBlock()
  if here.color >= chromMax: return
  if t.node.fund.len() > 0: return
  let order = t.currentOrder.order
  if order == Terminate: return
  if order == Push and
    t.currentOrder.args[0].parseInt() != here.sameBlocks.len(): return
  t.decide(order, (0, 1))

proc goWhite(t: Target) =
  let here = t.node.currentBlock()
  if here.color == WhiteNumber:
    let (dx, dy) = t.node.dp.getdXdY()
    let (nx, ny) = (t.node.x+dx, t.node.y+dy)
    if not t.node.mat.isIn(nx, ny): return
    let next = t.node.mat[nx, ny]
    if next != nil:
      if next.color == BlackNumber: return # 悪しき白->黒
      if next.color == WhiteNumber:
        let nextNode = t.node.newNodeIt:
          it.x = nx
          it.y = ny
        store(t.env, nextNode, t.ord)
        return
      # 交差した時は,ループに陥らないよう,今のままのdpccで行けるかチェック
      if next.endPos[t.node.cc, t.node.dp].used: return
      let nextNode = t.node.newNodeIt:
        it.x = nx
        it.y = ny
      store(t.env, nextNode, t.ord)
      return
    doAssert chromMax == WhiteNumber
    for c in 0..chromMax:
      let (ok, newVal, newMat) = t.tryUpdate((nx, ny, c.PietColor), (0, 0))
      if not ok: continue
      let nextNode = t.node.newNodeIt:
        it.val = newVal
        it.x = nx
        it.y = ny
        it.mat = newMat
      store(t.env, nextNode, t.ord)
    return
  else:
    if not t.tryUpdateNotVisited(WhiteNumber, (0, 0), onlyNil = true): return
    var newMat = t.node.mat.deepCopy()
    let (ok, nx, ny, dp, cc) = newMat.toNextState(t.node)
    if not ok: quit("yabee")
    var newVal = t.node.val
    if newMat[nx, ny] != nil: quit("yabee")
    if not t.env.update((nx, ny, WhiteColor), newMat, newVal): return
    let nextNode = newNode(newVal, nx, ny, newMat, dp, cc,
        t.node.fund.deepCopy())
    store(t.env, nextNode, t.ord)

proc pushBlack(t: Target) =
  let here = t.node.currentBlock
  if here.color >= chromMax: return # 白で壁にぶつからないように
  if not t.tryUpdateNotVisited(BlackNumber, (0, 0), onlyNil = true): return
  let (ok, dp, cc) = t.node.searchNotVisited()
  if not ok: quit("yabee")
  var newMat = t.node.mat.deepCopy()
  let (nx, ny) = newMat[t.node.x, t.node.y].endPos.getNextPos(dp, cc)
  var newVal = t.node.val
  if newMat[nx, ny] != nil: quit("yabee")
  if not t.env.update((nx, ny, BlackColor), newMat, newVal): return
  let nextNode = t.node.newNodeIt:
    it.val = newVal
    it.mat = newMat
  store(t.env, nextNode, t.ord)

template doFundIt(t: Target, order: Order, dFund: int,
    operation: untyped): untyped =
  let here = t.node.currentBlock
  if here.color < chromMax:
    t.decide(order, (dFund, 0), proc(node: var Node): bool =
      let it{.inject.} = node # ref なのであとで代入すればいいよね
      operation
      node = it
      return true)

proc doFund(t: Target) =
  t.doFundIt(Push, 1): it.fund.push(it.mat[it.x, it.y].sameBlocks.len())
  if t.node.fund.len() > 0:
    t.doFundIt(Pop, -1): discard it.fund.pop()
    t.doFundIt(Pointer, -1): it.dp.toggle(it.fund.pop())
    t.doFundIt(Switch, -1):
      if it.fund.pop() mod 2 == 1: it.cc.toggle()
    t.doFundIt(Not, 0): it.fund.push(if it.fund.pop() == 0: 1 else: 0)
    t.doFundIt(Dup, 1): it.fund.push(it.fund.top())
  if t.node.fund.len() > 1:
    t.doFundIt(Add, -1):
      let top = it.fund.pop()
      let next = it.fund.pop()
      it.fund.push(next + top)
    t.doFundIt(Sub, -1):
      let top = it.fund.pop()
      let next = it.fund.pop()
      it.fund.push(next - top)
    t.doFundIt(Mul, -1):
      let top = it.fund.pop()
      let next = it.fund.pop()
      it.fund.push(next * top)
    t.doFundIt(Div, -1):
      let top = it.fund.pop()
      let next = it.fund.pop()
      if top == 0: return false
      it.fund.push(next div top)
    t.doFundIt(Mod, -1):
      let top = it.fund.pop()
      let next = it.fund.pop()
      if top == 0: return false
      it.fund.push(next mod top)
    t.doFundIt(Greater, -1):
      let top = it.fund.pop()
      let next = it.fund.pop()
      it.fund.push(if next > top: 1 else: 0)
    t.doFundIt(Roll, -2):
      let top = it.fund.pop()
      let next = it.fund.pop()
      if next > it.fund.len(): return false
      if next < 0: return false
      if top < 0: return false
      var roll = newSeq[int]()
      for i in 0..<next: roll.add(it.fund.pop())
      for i in 0..<next: it.fund.push(roll[(i + top) mod next])

proc setupNextFronts(env: NodeEnv) =
  let nextItems = (proc(): seq[seq[seq[Node]]] =
    result = newSeqWith(env.orders.len()+1, newSeqWith(env.maxFundLevel,
        newSeq[Node]()))
    for i in 0..<env.nexts.len():
      var next = env.nexts[i]
      for j in 0..<next.len():
        result[i][j] &= env.nexts[i][j].items()
    )()
  env.fronts = nextItems.mapIt(it.mapIt(it.sorted((a, b)=>a.val-b.val)))

proc checkIterateResult(env: NodeEnv): bool =
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

proc getResult(env: NodeEnv): Matrix[PietColor] =
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


proc processFront(env: NodeEnv, ord: int) =
  let front = env.getFront(ord)
  if ord == env.orders.len():
    env.processLastOrder(front, ord)
    return
  for f in front:
    let target: Target = (env, f, ord)
    target.extendBlock()
    target.doOrder()
    target.pushBlack()
    target.goWhite()
    target.doFund()
    # 6. Terminate -> 今のブロックの位置配列から増やしまくるのを20個程度して終わらせる

proc quasiStegano2D*(env: NodeEnv): Matrix[PietColor] =
  for progress in 0..<(env.width * env.height): # 最悪全部塗り終わるまで繰り返す
    env.prepare()
    for ord in 0..env.orders.len():
      # if ord < maxNonNilFrontIndex - maxTrackBackOrderLen : continue
      env.processFront(ord)
    env.setupNextFronts()
    if not env.checkIterateResult(): break
  return env.getResult()

if isMainModule:
  printMemories()
  if commandLineParams().len() == 0:
    #let orders = makeRandomOrders(20)
    # let baseImg = makeLocalRandomPietColorMatrix(12,12)
    # echo baseImg.toConsole()
    # discard quasiStegano2D(orders,baseImg,400).toConsole()
    discard
  else:
    let baseImg = commandLineParams()[0].newPietMap().pietColorMap
    proc getOrders(): seq[PasmOrder] =
      result = @[]
      proc d(ord: Order, n: int = -1): tuple[ord: Order, arg: seq[string]] =
        if n <= 0 and ord != Push: return (ord, @[])
        else: return (ord, @[$n])
      let orders = @[
        d(Push, 3), d(Dup), d(Mul), d(Dup), d(Mul), d(Push, 1), d(Sub), d(Dup),
            d(OutC),
        d(Push, 3), d(Dup), d(Push, 1), d(Add), d(Add), d(Sub), d(Dup), d(
            OutC),
        d(Push, 2), d(Dup), d(Add), d(Sub), d(Dup), d(OutC),
        d(Push, 3), d(Dup), d(Push, 2), d(Add), d(Mul), d(Add), d(OutC)
      ]
      for i in 0..<1:
        for oa in orders:
          let (order, args) = oa
          result &= (ExecOrder, order, args)
      result &= (MoveTerminate, Terminate, @[])
    let orders = getOrders()
    # let orders = makeRandomOrders((baseImg.width.float * baseImg.height.float * 0.1).int)
    echo orders
    echo baseImg.toConsole()
    var sw = newStopWatch()
    sw.start()
    let stegano = newEnv(baseImg, orders).quasiStegano2D()
    sw.stop()
    echo sw
    stegano.save("./piet.png", codelSize = 10)
