{.experimental: "notnil".}
import packages/[common, pietbase, frompiet, curse]
import pasm, steganoutil, blockinfo, node
import sets, hashes, tables

type Target* = tuple[env: NodeEnv, node: Node, ord: int]
# スキップ関数
proc searchNotVisited(node: Node): NotVisited =
  searchNotVisited(node.mat, node.x, node.y, node.dp, node.cc)
proc currentBlock(node: Node): BlockInfo = node.mat[node.x, node.y]
proc currentEndPos(node: Node): EightDirection[UsedInfo] =
  node.currentBlock().endPos
proc nextKey(t: Target, d: Key): Key =
  (t.node.fund.len() + d.fund, t.ord + d.ord)
proc currentOrder(t: Target): PasmOrder = t.env.orders[t.ord]
proc toNextState(mat: var Matrix[BlockInfo], node: Node): NextStateResult =
  mat.toNextState(node.x, node.y, node.dp, node.cc)
# storedValueや過去の制約をチェックして,更新できれば新しい結果を返す
proc tryUpdate(t: Target, c: Codel, dKey: Key):
    tuple[ok: bool, val: int, mat: Matrix[BlockInfo]] =
  template mistaken(): untyped = (false, -1, newMatrix[BlockInfo](0, 0))
  block: # 一回試してみる
    var tmpVal = t.node.val
    t.env.update(c, tmpVal)
    if t.env.getStoredWorstVal(t.nextKey(dKey)) <= tmpVal: return mistaken
  var newMat = t.node.mat.deepCopy()
  var newVal = t.node.val
  if not t.env.update(c, newMat, newVal): return mistaken
  return (true, newVal, newMat)
# 未踏の地 でかつ storedValueや過去の制約を満たすかどうかチェック
proc tryUpdateNotVisited(t: Target, color: PietColor, dKey: Key,
    onlyNil: bool = false,
    onlySameColor: bool = false,
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

# 偶然同じ画像が作られてしまうことがあるので,確認しつつ上位の値を保存
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

# 8方向とも全て塞がっているか確認し,そうであれば+1に値を保存
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

# ブロック内 内の 1codel を伸ばしてみる
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

# 命令を実行し,dKeyに保存する
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

# 命令を全て完了した場合はそのコピーを置く
proc processLastOrder(env: NodeEnv, front: seq[Node], ord: int) =
  if ord != env.orders.len(): return
  if front.len() > 0: env.completedMin = front.mapIt(it.val).max() + 1
  for f in front: store(env, f, ord)
  if front.len() > 0: env.completedMin = front.mapIt(it.val).min()

# 今しなければならない命令を実行する
proc doOrder(t: Target) =
  let here = t.node.currentBlock()
  if here.color >= chromMax: return
  if t.node.fund.len() > 0: return
  let order = t.currentOrder.order
  if order == Terminate: return
  if order == Push and
    t.currentOrder.args[0].parseInt() != here.sameBlocks.len(): return
  t.decide(order, (0, 1))

# 行き先に白を置いてみる
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

# 行き先に黒を置いてみる
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

# 余剰分を変更するような操作
template doFundIt(t: Target, order: Order, dFund: int,
    operation: untyped): untyped =
  let here = t.node.currentBlock
  if here.color < chromMax:
    t.decide(order, (dFund, 0), proc(node: var Node): bool =
      let it{.inject.} = node # ref なのであとで代入すればいいよね
      operation
      node = it
      return true)

# 余剰分を変更するような操作を全て試す
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

# 全部試す
proc processFront*(env: NodeEnv, ord: int) =
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
