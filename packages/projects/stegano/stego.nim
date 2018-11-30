{.experimental: "notnil".}
import packages/[common,pietbase,frompiet,curse]
import pasm,steganoutil,blockinfo
import sets,hashes,tables



type
  NodeObject = object
    val,x,y:int
    mat:Matrix[BlockInfo]
    dp:DP
    cc:CC
    fund:Stack[int]
  Node = ref NodeObject not nil
  NodeEnv = ref object
    img:Matrix[PietColor]
    orders:seq[PasmOrder]
    maxFrontierNum :int
    maxFundLevel :int
    maxTrackBackOrderLen :int
    fronts:seq[seq[seq[Node]]]
    nexts: seq[seq[BinaryHeap[Node]]]
    stored:seq[seq[HashSet[Hash]]]
    maxNonNilFrontIndex:int
    maxFunds:seq[int]
    completedMin : int

proc width(env:NodeEnv) : int = env.img.width
proc height(env:NodeEnv) : int = env.img.height

proc newNode(val,x,y:int,mat:Matrix[BlockInfo],dp:DP,cc:CC,fund:Stack[int]) : Node =
  new(result)
  result.val = val
  result.x = x
  result.y = y
  result.mat = mat
  result.dp = dp
  result.cc = cc
  result.fund = fund
# val(add distance),mat(update to the color)
type State = tuple[x,y:int,color:PietColor,ord:int]
proc update(val:var int,color,baseColor:PietColor) =
  val += distance(color,baseColor)
  # 色に元画像の出現割合に応じて重み付けするとお得?
  # val += (distance(color,base[x,y]).float * weights[color.int]).int
proc update(env: NodeEnv,mat:var Matrix[BlockInfo],s:State) :bool =
  proc canUpdateEndPos(e:var EightDirection[UsedInfo],x,y:int) : bool =
    # 使用済みのところを更新してしまうと駄目(false)
    result = true
    let newPos = (x.int16,y.int16)
    template update(dir) =
      if dir.used : return false
      dir.pos = newPos
    if y < e.upR.pos.y or y == e.upR.pos.y and x > e.upR.pos.x : e.upR.update()
    if y < e.upL.pos.y or y == e.upL.pos.y and x < e.upL.pos.x : e.upL.update()
    if y > e.downR.pos.y or y == e.downR.pos.y and x < e.downR.pos.x : e.downR.update()
    if y > e.downL.pos.y or y == e.downL.pos.y and x > e.downL.pos.x : e.downL.update()
    if x < e.leftR.pos.x or x == e.leftR.pos.x and y < e.leftR.pos.y : e.leftR.update()
    if x < e.leftL.pos.x or x == e.leftL.pos.x and y > e.leftL.pos.y : e.leftL.update()
    if x > e.rightR.pos.x or x == e.rightR.pos.x and y > e.rightR.pos.y : e.rightR.update()
    if x > e.rightL.pos.x or x == e.rightL.pos.x and y < e.rightL.pos.y : e.rightL.update()
  template syncSameBlocks(blockInfo:BlockInfo) =
    for index in blockInfo.sameBlocks : mat.data[index] = blockInfo
  doAssert mat[s.x,s.y] == nil
  if s.color == WhiteNumber:
    mat[s.x,s.y] = whiteBlockInfo
    return true
  if s.color == BlackNumber:
    mat[s.x,s.y] = blackBlockInfo
    return true
  let adjasts = mat.checkAdjasts(s.x,s.y,s.color)
  if adjasts.len() == 0 : # 新規
    mat[s.x,s.y] = env.img.newBlockInfo(s.x,s.y,s.color)
    return true
  for adjast in adjasts: # そもそも全部結合していいやつかチェック
    if adjast.sizeFix : return false
  # とりあえず自身をコピーした0番に結合
  let zeroBlock = adjasts[0].deepCopy()
  zeroBlock.sameBlocks &= env.img.getI(s.x,s.y)
  if not zeroBlock.endPos.canUpdateEndPos(s.x,s.y) : return false
  template connect(adjast) = # コピーが作成されているゼロ番に結合
    let newBlock = adjast.deepCopy()
    # チェック
    for b in zeroBlock.sameBlocks:
      let (bx,by) = env.img.getXY(b)
      if not newBlock.endPos.canUpdateEndPos(bx,by) : return false
    for b in newBlock.sameBlocks:
      let (bx,by) = env.img.getXY(b)
      if not zeroBlock.endPos.canUpdateEndPos(bx,by) : return false
    # 使用済みを共有
    for ccdp in allCCDP():
      let (cc,dp) = ccdp
      let used = zeroBlock.endPos[cc,dp].used or newBlock.endPos[cc,dp].used
      zeroBlock.endPos[cc,dp] = (used,zeroBlock.endPos[cc,dp].pos)
    # 更新
    zeroBlock.sameBlocks &= newBlock.sameBlocks
  for l in 1..<adjasts.len(): adjasts[l].connect()
  zeroBlock.syncSameBlocks()
  return true
proc update(env:NodeEnv,s:State,mat:var Matrix[BlockInfo],val:var int) : bool =
  val.update(s.color,env.img[s.x,s.y])
  return env.update(mat,s)

proc newEnv(img:Matrix[PietColor],orders:seq[PasmOrder]) : NodeEnv =
  proc setupFirstFront(env:NodeEnv) =
    for c in 0..<chromMax:
      var initMat = newMatrix[BlockInfo](env.width,env.height) # 全てnil
      var val = 0
      if not env.update(initMat,val,0,0,c.PietColor) : quit("yabee")
      env.fronts[0][0] &= newNode(val,0,0,initMat,newDP(),newCC(),newStack[int]())
  new(result)
  result.img = img
  result.orders = orders
  result.maxFrontierNum = 720
  result.maxFundLevel = 6
  result.maxTrackBackOrderLen = 30
  result.fronts = newSeqWith(orders.len()+1,newSeqWith(result.maxFundLevel,newSeq[Node]()))
  result.setupFirstFront()
  result.completedMin = EPS
  doAssert result.width < int16.high and result.height < int16.high

proc getFront(env:NodeEnv,ord:int) : seq[Node] =
  result = @[]
  for fr in env.fronts[ord]:
    for f in fr:
      result &= f

proc prepare(env:NodeEnv) =
  env.nexts = newSeqWith( env.orders.len()+1, newSeqWith(env.maxFundLevel,newBinaryHeap[Node](proc(x,y:Node):int= y.val - x.val)))
  # top()が一番雑魚
  env.stored = newSeqWith( env.orders.len()+1, newSeqWith(env.maxFundLevel,initSet[Hash]()))
  env.maxNonNilFrontIndex = toSeq(0..<env.fronts.len()).filterIt(env.fronts[it].mapIt(it.len()).sum() > 0).max()
  env.maxFunds = toSeq(0..<env.maxFundLevel).mapIt(env.maxFrontierNum div (1 + 4 * it))

proc getMaxFunds(env:NodeEnv,fundLevel,ord:int):int =
  let trackbacked = (ord - env.maxNonNilFrontIndex + env.maxTrackBackOrderLen).float /  env.maxTrackBackOrderLen.float
  return int(env.maxFunds[fundLevel].float * max(1.0,trackbacked))

# 命令を実行できる人の方が偉いので強い重みをつける()
proc getStoredWorstVal(env:NodeEnv,fundLevel,ord:int):int =
  if fundLevel >= env.maxFundLevel : return -1 # 越えたときも-1で簡易的に弾く
  if env.nexts[ord][fundLevel].len() < env.getMaxFunds(fundLevel,ord) : return min(EPS,env.completedMin)
  if env.nexts[ord][fundLevel].len() == 0 : return min(EPS,env.completedMin)
  return min(env.nexts[ord][fundLevel].top().val,env.completedMin)

# 偶然にも全く同じ画像が作られてしまうことがあるので,同じものがないかを確認してhashを取る必要がある
proc store(env:NodeEnv,node:Node,ord:int) =
  let fundLevel = node.fund.len()
  if fundLevel >= env.maxFundLevel : return
  if env.getStoredWorstVal(fundLevel,ord) <= node.val : return
  let hashing = node.mat.hashing
  if hashing in env.stored[ord][fundLevel]: return
  env.nexts[ord][fundLevel].push(node)
  env.stored[ord][fundLevel].incl(hashing)
  if env.nexts[ord][fundLevel].len() > env.getMaxFunds(fundLevel,ord)  :
    # exclしなくてもいいかな
    discard env.nexts[ord][fundLevel].pop()

proc tryUpdate(env:NodeEnv,n:Node,s:State,dOrd,dFund:int) : tuple[ok:bool,val:int,mat:Matrix[BlockInfo]] =
  template mistaken() : untyped = (false,-1,newMatrix[BlockInfo](0,0))
  block: # 一回試してみる
    var tmpVal = n.val
    update(tmpVal,s.color,env.img[s.x,s.y])
    if env.getStoredWorstVal(n.fund.len()+dFund,s.ord + dOrd) <= tmpVal : return mistaken
  var newMat = n.mat.deepCopy()
  var newVal = n.val
  if not env.update(s,newMat,newVal) : return mistaken
  return (true,newVal,newMat)
proc tryUpdateNotVisited(env:NodeEnv,n:Node,color:PietColor,dOrd,dFund:int,onlyNil:bool = false,onlySameColor:bool=false,onlyNotUsedCCDP:bool=false) : bool =
  # 一回試してみる(+nilなら更新した時のコストもチェック)
  let (ok,dp,cc) = n.mat.searchNotVisited(n.x,n.y,n.dp,n.cc)
  if not ok : return false
  let (nx,ny) = n.mat[n.x,n.y].endPos.getNextPos(dp,cc)
  if n.mat[nx,ny] == nil:
    var tmpVal = n.val
    tmpVal.update(color,env.img[nx,ny])
    if env.getStoredWorstVal(n.fund.len()+dFund,s.ord + dOrd) <= tmpVal : return false
    return true
  # そもそも空いて無いと駄目
  if onlyNil : return false
  # 交差した時だと思うけれども同じ色しか駄目
  if onlySameColor and n.mat[nx,ny].color != color : return false
  # 交差した時に,ループに陥らないよう,今のままのdpccで行けるかチェック
  if onlyNotUsedCCDP and n.mat[nx,ny].endPos[cc,dp].used : return false
  return true

proc checkTerminate(f:Node) =
  var newMat = f.mat.deepCopy()
  var dp = f.dp
  var cc = f.cc
  var newVal = f.val
  for i in 0..<8:
    let (nX,nY) = newMat.updateUsingNextPos(f.x,f.y,dp,cc)
    if base.isIn(nX,nY):
      if newMat[nX,nY] == nil :
        if not base.update(newMat,newVal,nX,nY,BlackNumber) : return
      elif newMat[nX,nY].color != BlackNumber: return
    if i mod 2 == 0 : cc.toggle()
    else: dp.toggle(1)
  let nextNode = newNode(newVal,f.x,f.y,newMat,dp,cc,f.fund.deepCopy())
  nextNode.store(ord+1)

proc extendBlock(f:Node) =
  let here = f.mat[f.x,f.y]
  if here.color >= chromMax : return
  for b in here.sameBlocks:
    let (bx,by) = base.getXY(b)
    for dxdy in dxdys:
      let (dx,dy) = dxdy
      let (nx,ny) = (bx + dx,by + dy)
      if not base.isIn(nx,ny) : continue
      let ext = f.mat[nx,ny]
      if ext != nil : continue
      let (ok,newVal,newMat) = f.tryUpdate(nx,ny,here.color,0,0)
      if not ok : continue
      let nextNode = newNode(newVal,nx,ny,newMat,f.dp,f.cc,f.fund.deepCopy())
      nextNode.store(ord)
      if order.order == Terminate: nextNode.checkTerminate()

proc decide(f:Node,order:Order,dOrd,dFund:int,callback:proc(_:var Node):bool = (proc(_:var Node):bool=true)) =
  let here = f.mat[f.x,f.y]
  let color = here.color.getNextColor(order).PietColor
  if not f.tryUpdateNotVisited(color,dOrd,dFund,onlySameColor=true,onlyNotUsedCCDP=true) : return
  var newMat = f.mat.deepCopy()
  let (ok,nx,ny,dp,cc) = newMat.toNextState(f.x,f.y,f.dp,f.cc)
  if not ok : quit("yabee")
  if newMat[nx,ny] != nil :
    let next = newMat[nx,ny]
    if next.color != color or next.endPos[cc,dp].used : quit("yabee")
    var nextNode = newNode(f.val,nx,ny,newMat,dp,cc,f.fund.deepCopy())
    if not nextNode.callback(): return
    nextNode.store(ord+dOrd)
    return
  var newVal = f.val
  if not base.update(newMat,newVal,nx,ny,color) : return
  var nextNode = newNode(newVal,nx,ny,newMat,dp,cc,f.fund.deepCopy())
  if order == Push : newMat[f.x,f.y].sizeFix = true
  if not nextNode.callback(): return
  nextNode.store(ord+dOrd)

proc processLastOrder(env:NodeEnv,front:seq[Node]):
  if ord != env.orders.len(): return
  if front.len() > 0 : env.completedMin = front.mapIt(it.val).max() + 1
  for f in front: env.store(f,ord)
  if front.len() > 0 : env.completedMin = front.mapIt(it.val).min()

proc doOrder(f:Node) =
  let here = f.mat[f.x,f.y]
  if here.color >= chromMax : return
  if f.fund.len() > 0 : return
  if order.order == Terminate: return
  if order.order == Push and order.args[0].parseInt() != here.sameBlocks.len() : return
  f.decide(order.order,1,0)
proc goWhite(f:Node) =
  let here = f.mat[f.x,f.y]
  if here.color == WhiteNumber:
    let (dx,dy) = f.dp.getdXdY()
    let (nx,ny) = (f.x+dx,f.y+dy)
    if not base.isIn(nx,ny) : return
    if f.mat[nx,ny] != nil:
      let next = f.mat[nx,ny]
      if next.color == BlackNumber : return # 悪しき白->黒
      if next.color == WhiteNumber :
        let nextNode = newNode(f.val,nx,ny,f.mat.deepCopy(),f.dp,f.cc,f.fund.deepCopy())
        nextNode.store(ord)
        return
      # 交差した時は,ループに陥らないよう,今のままのdpccで行けるかチェック
      if next.endPos[f.cc,f.dp].used : return
      var nextNode = newNode(f.val,nx,ny,f.mat.deepCopy(),f.dp,f.cc,f.fund.deepCopy())
      nextNode.store(ord)
      return
    doAssert chromMax == WhiteNumber
    for c in 0..chromMax:
      let (ok,newVal,newMat) = f.tryUpdate(nx,ny,c.PietColor,0,0)
      if not ok : continue
      let nextNode = newNode(newVal,nx,ny,newMat,f.dp,f.cc,f.fund.deepCopy())
      nextNode.store(ord)
    return
  else:
    if not f.tryUpdateNotVisited(WhiteNumber,0,0,onlyNil=true) : return
    var newMat = f.mat.deepCopy()
    let (ok,nx,ny,dp,cc) = newMat.toNextState(f.x,f.y,f.dp,f.cc)
    if not ok : quit("yabee")
    var newVal = f.val
    if newMat[nx,ny] != nil : quit("yabee")
    if not base.update(newMat,newVal,nx,ny,WhiteNumber) : return
    let nextNode = newNode(newVal,nx,ny,newMat,dp,cc,f.fund.deepCopy())
    nextNode.store(ord)
proc pushBlack(f:Node) =
  let here = f.mat[f.x,f.y]
  if here.color >= chromMax : return # 白で壁にぶつからないように
  if not f.tryUpdateNotVisited(BlackNumber,0,0,onlyNil=true) : return
  var newMat = f.mat.deepCopy()
  let (ok,dp,cc) = newMat.searchNotVisited(f.x,f.y,f.dp,f.cc)
  if not ok : quit("yabee")
  let (nx,ny) = newMat[f.x,f.y].endPos.getNextPos(dp,cc)
  var newVal = f.val
  if newMat[nx,ny] != nil : quit("yabee")
  if not base.update(newMat,newVal,nx,ny,BlackNumber) : return
  let nextNode = newNode(newVal,f.x,f.y,newMat,f.dp,f.cc,f.fund.deepCopy())
  nextNode.store(ord)
template doFundIt(f:Node,order:Order,dFund:int,operation:untyped) : untyped =
  (proc =
    let here = f.mat[f.x,f.y]
    # if true : return
    if here.color >= chromMax : return
    f.decide(order,0,dFund,proc(node:var Node) :bool=
      let it{.inject.} = node # ref なのであとで代入すればいいよね
      operation
      node = it
      return true)
  )()

proc doFund(f:Node) =
  f.doFundIt(Push,1): it.fund.push(it.mat[it.x,it.y].sameBlocks.len())
  if f.fund.len() > 0:
    f.doFundIt(Pop,-1): discard it.fund.pop()
    f.doFundIt(Pointer,-1): it.dp.toggle(it.fund.pop())
    f.doFundIt(Switch,-1):
      if it.fund.pop() mod 2 == 1 : it.cc.toggle()
    f.doFundIt(Not,0) : it.fund.push(if it.fund.pop() == 0: 1 else: 0)
    f.doFundIt(Dup,1) : it.fund.push(it.fund.top())
  if f.fund.len() > 1:
    f.doFundIt(Add,-1) :
      let top = it.fund.pop()
      let next = it.fund.pop()
      it.fund.push(next + top)
    f.doFundIt(Sub,-1) :
      let top = it.fund.pop()
      let next = it.fund.pop()
      it.fund.push(next - top)
    f.doFundIt(Mul,-1) :
      let top = it.fund.pop()
      let next = it.fund.pop()
      it.fund.push(next * top)
    f.doFundIt(Div,-1) :
      let top = it.fund.pop()
      let next = it.fund.pop()
      if top == 0 : return false
      it.fund.push(next div top)
    f.doFundIt(Mod,-1) :
      let top = it.fund.pop()
      let next = it.fund.pop()
      if top == 0 : return false
      it.fund.push(next mod top)
    f.doFundIt(Greater,-1) :
      let top = it.fund.pop()
      let next = it.fund.pop()
      it.fund.push(if next > top : 1 else:0)
    f.doFundIt(Roll,-2) :
      let top = it.fund.pop()
      let next = it.fund.pop()
      if next > it.fund.len() : return false
      if next < 0 : return false
      if top < 0 : return false
      var roll = newSeq[int]()
      for i in 0..<next: roll.add(it.fund.pop())
      for i in 0..<next: it.fund.push(roll[(i + top) mod next])

proc setupNextFronts(env:NodeEnv) =
  let nextItems = (proc():seq[seq[seq[Node]]]=
    result = newSeqWith(orders.len()+1,newSeqWith(maxFundLevel,newSeq[Node]()))
    for i in 0..<nexts.len():
      var next = nexts[i]
      for j in 0..<next.len():
        result[i][j] &= nexts[i][j].items()
    )()
  env.fronts = nextItems.mapIt(it.mapIt(it.sorted((a,b)=>a.val-b.val)))

proc checkIterateResult(env:NodeEnv) : bool =
  result = true
  let maxes =  fronts.mapIt(it.mapIt(it.len()).sum())
  for i in 0..<fronts.len():
    let front = fronts[^(1+i)]
    if front.len() == 0 : continue
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
      echo front[0][j].mat.toConsole(),front[0][0].val,"\n"
      # echo front[0][j].mat.toPietColorMap().newGraph().mapIt(it.orderAndSizes.mapIt(it.pasmType))
      echo "progress: ",progress
      echo "memory  :" ,getTotalMem() div 1024 div 1024,"MB"
    break
  if maxes[^1] > 0 and maxes[^2] == 0 and maxes[^3] == 0 :
    return false

proc getResult(env:NodeEnv) : Matrix[PietColor] =
  var front = fronts[^1][0]
  proc embedNotdecided(f:var Node) =
    let initMat = f.mat.deepCopy()
    for x in 0..<f.mat.width:
      for y in 0..<f.mat.height:
        if f.mat[x,y] != nil: continue
        let color = base[x,y]
        let adjast = (proc(f:var Node) :bool =
          for dxdy in dxdys:
            let (dx,dy) = dxdy
            let (nx,ny) = (x+dx,y+dy)
            if not base.isIn(nx,ny) : continue
            if initMat[nx,ny] == nil : continue
            if initMat[nx,ny].color == color : return true
          return false
        )(f)
        if color < chromMax and adjast : continue
        if not base.update(f.mat,f.val,x,y,color): quit("yabeeyo")
    # 隣接しているので一番近い色を埋める
    for x in 0..<f.mat.width:
      for y in 0..<f.mat.height:
        if f.mat[x,y] != nil: continue
        let color = base[x,y]
        var newMat = f.mat.deepCopy()
        var newVal = f.val
        if base.update(newMat,newVal,x,y,color) :
          f.mat = newMat
          f.val = newVal
          continue
        type Try = tuple[success:bool,mat:Matrix[BlockInfo],val:int]
        var tries = newSeq[Try]()
        for c in 0..<chromMax:
          var success = false
          var newMat = f.mat.deepCopy()
          var newVal = f.val
          if base.update(newMat,newVal,x,y,c.PietColor) :
            success = true
          tries &= (success,newMat,newVal)
        tries = tries.filterIt(it.success).sorted((a,b)=> a.val - b.val)
        f.mat = tries[0].mat
        f.val = tries[0].val
  proc findEmbeddedMinIndex():int =
    var minIndex = 0
    var minVal = EPS
    for i,f in front:
      front[i].embedNotdecided()
      if minVal < front[i].val : continue
      minIndex = i
      minVal = front[i].val
    return minIndex


  doAssert front.len() > 0
  let mats = front.mapIt(it.mat.deepCopy())
  let index = findEmbeddedMinIndex()
  result = front[index].mat.toPietColorMap()
  echo "result: before\n",mats[index].toPietColorMap().toConsole()
  echo "result :\n",result.toConsole(),front[index].val
  echo "base   :\n",base.toConsole()
  echo mats[index].toPietColorMap().newGraph().mapIt(it.orderAndSizes.mapIt(it.order))
  echo result.newGraph().mapIt(it.orderAndSizes.mapIt(it.order))
  echo orders


proc processFront(env:NodeEnv,ord:int) =
  let front = env.getFront(ord)
  if ord == env.orders.len():
    env.processLastOrder(front)
    continue
  #let order = env.orders[ord]
  for f in front:
    f.extendBlock()
    f.doOrder()
    f.pushBlack()
    f.goWhite()
    f.doFund()
    # 6. Terminate -> 今のブロックの位置配列から増やしまくるのを20個程度して終わらせる

proc quasiStegano2D*(env:NodeEnv) :Matrix[PietColor]=
  for progress in 0..<(env.width * env.height): # 最悪全部塗り終わるまで繰り返す
    env.prepare()
    for ord in 0..env.orders.len():
      # if ord < maxNonNilFrontIndex - maxTrackBackOrderLen : continue
      env.processFront(ord)
    env.setupNextFronts()
    if not env.checkIterateResult() : break
  return env.getResult()

if isMainModule:
  printMemories()
  if commandLineParams().len() == 0 :
    #let orders = makeRandomOrders(20)
    # let baseImg = makeLocalRandomPietColorMatrix(12,12)
    # echo baseImg.toConsole()
    # discard quasiStegano2D(orders,baseImg,400).toConsole()
    discard
  else:
    let baseImg = commandLineParams()[0].newPietMap().pietColorMap
    proc getOrders():seq[PasmOrder] =
      result = @[]
      proc d(ord:Order,n:int = -1):tuple[ord:Order,arg:seq[string]] =
        if n <= 0 and ord != Push : return (ord,@[])
        else: return (ord,@[$n])
      let orders = @[
        d(Push,3),d(Dup),d(Mul),d(Dup),d(Mul),d(Push,1),d(Sub),d(Dup),d(OutC),
        d(Push,3),d(Dup),d(Push,1),d(Add),d(Add),d(Sub),d(Dup),d(OutC),
        d(Push,2),d(Dup),d(Add),d(Sub),d(Dup),d(OutC),
        d(Push,3),d(Dup),d(Push,2),d(Add),d(Mul),d(Add),d(OutC)
      ]
      for i in 0..<2:
        for oa in orders:
          let (order,args) = oa
          result &= (ExecOrder,order,args)
      result &= (MoveTerminate,Terminate,@[])
    let orders = getOrders()
    # let orders = makeRandomOrders((baseImg.width.float * baseImg.height.float * 0.1).int)
    echo orders
    echo baseImg.toConsole()
    var sw = newStopWatch()
    sw.start()
    let stegano = newEnv(baseImg,orders).quasiStegano2D()
    sw.stop()
    echo sw
    stegano.save("./piet.png",codelSize=10)