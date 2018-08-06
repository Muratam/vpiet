import common
import pietbase
import pietmap
import pietize
import curse
import makegraph
import sets
import colordiff
import hashes
# 人間の誤り訂正能力を調べてみて,重みマスクをつけるとよりよさそう
# 分岐: if / while のみの分岐とすればまだまともなものが作れるのではないか??
#    : if :: 分岐した二箇所がうまくつながるように幅優先的に処理していき,
#       : ⬇の重みは命令が進むにつれてでかくなるようにすればきれい??
#       : 二人が近いほどコストが低いように設定すればつながりやすい??
#    : while :: 指定した点に近いほどコストが低いように設定すればつながりやすい??
const chromMax = hueMax * lightMax
const EPS = 1e12.int
const dxdys = [(0,1),(0,-1),(1,0),(-1,0)]


proc `$`(orders:seq[OrderAndArgs]):string =
  result = ""
  for order in orders:
    case order.order :
    of Operation:
      if order.operation == Push : result &= "+" & order.args[0]
      else: result &= $order.operation
    else: result &= $order.order
    result &= " "

var colorTable = newSeqWith(PietColor.high.int+1,newSeqWith(Order.high.int+1,-1))
proc getNextColor(i:int,operation:Order):int = #i.PietColor.decideNext(operation)
  if colorTable[i][operation.int] == -1:
    colorTable[i][operation.int] = i.PietColor.decideNext(operation)
  return colorTable[i][operation.int]

proc checkStegano1D(orders:seq[OrderAndArgs],base:Matrix[PietColor]) =
  if pietOrderType != TerminateAtGreater:
    quit("only TerminateAtGreater is allowed")
  # orders : inc dup ... push terminate
  doAssert orders[^1].operation == Terminate         ,"invalid"
  doAssert orders[0..^2].allIt(it.order == Operation),"invalid"
  doAssert base.height == 1
  doAssert base.width >= orders.len()

proc stegano1D*(orders:seq[OrderAndArgs],base:Matrix[PietColor]) =
  checkStegano1D(orders,base)
  # result = newMatrix[PietColor](base.width,1)
  # https://photos.google.com/photo/AF1QipMlNFgMkP-_2AtsRZcYbPV3xkBjU0q8bKxql9p3?hl=ja
  # 有彩色 + 白 (黒は使用しない)
  type DPKey = tuple[color,nop,ord,fund:int]  # [color][Nop][Order][Fund]
  type DPVal = tuple[val:int,preKey:DPKey] # Σ,前のやつ
  const initDPKey :DPKey = (0,0,0,0)
  const maxFund = 10
  var dp = newSeqWith(chromMax + 1,newSeqWith(base.width,newSeqWith(base.width,newSeq[DPVal]())))
  proc `[]` (self:var seq[seq[seq[seq[DPVal]]]],key:DPKey) : DPVal =
    doAssert self[key.color][key.nop][key.ord].len() > key.fund
    self[key.color][key.nop][key.ord][key.fund]
  block: # 最初は白以外
    let color = base[0,0]
    for i in 0..<chromMax:
      dp[i][0][0] = @[(distance(color,i.PietColor),initDPKey)]
  for progress in 0..<(base.width-1):
    # if progress mod 10 == 0 : echo progress
    let baseColor = base[progress+1,0]
    proc diff(color:int) : int = distance(baseColor,color.PietColor)
    proc update(pre,next:DPKey) =
      if dp[pre.color][pre.nop][pre.ord].len() == 0 : return
      if dp[pre].val >= EPS: return
      let nextDp = dp[next.color][next.nop][next.ord]
      let nextVal = dp[pre].val + diff(next.color)
      let dpVal = (nextVal,pre)
      if nextDp.len() <= next.fund :
        if nextDp.len() == next.fund:
          dp[next.color][next.nop][next.ord] &= dpVal
        else:
          for i in 0..<(next.fund-nextDp.len()): # WARN
            dp[next.color][next.nop][next.ord] &= (EPS,initDPKey)
          dp[next.color][next.nop][next.ord] &= dpVal
      elif nextVal >= dp[next].val: return
      else: dp[next.color][next.nop][next.ord][next.fund] = dpVal
    for nop in 0..progress:
      let ord = progress - nop
      # もう命令を全て終えた
      if ord >= orders.len(): continue
      let order = orders[ord]
      proc here(color:int): seq[DPVal] = dp[color][nop][ord]
      proc d(color,dNop,dOrd,f:int) : DPKey = (color,nop+dNop,ord+dOrd,f)
      # 命令を進めた
      for i in 0..<chromMax:
        update(d(i,0,0,0),d(i.getNextColor(order.operation),0,1,0))
      # Nop (白 -> 白)
      for f in 0..<here(chromMax).len():
        update(d(chromMax,0,0,f),d(chromMax,1,0,f))
      # Nop ([]->白)
      for i in 0..<chromMax:
        for f in 0..<here(i).len():
          update(d(i,0,0,f),d(chromMax,1,0,f))
      # Nop (白->[])
      for f in 0..<here(chromMax).len():
        for i in 0..<chromMax:
          update(d(chromMax,0,0,f),d(i,1,0,f))
      # Fund
      for i in 0..<chromMax:
        if false:
          # そんなわけないが任意の色に行けるとする場合(これはめちゃくちゃうまく行かなければおかしい)
          for j in 0..<chromMax:
            for f in 0..<here(i).len():
              update(d(i,0,0,f),d(j,1,0,f+1))
            for f in 1..<here(i).len():
              update(d(i,0,0,f),d(j,1,0,f-1))
        else:
          # 普通
          if ord+1 < orders.len() and orders[ord+1].operation != Push:
            update(d(i,0,0,0),d(i,1,0,0)) # 次Pushがわかってるのに増やすことはできない
          for f in 0..<min(here(i).len(),maxFund-1):
            update(d(i,0,0,f),d(i.getNextColor(Push),1,0,f+1))
          for f in 1..<min(here(i).len(),maxFund-1):
            update(d(i,0,0,f),d(i,1,0,f))
            update(d(i,0,0,f),d(i.getNextColor(Pop),1,0,f-1))
            update(d(i,0,0,f),d(i.getNextColor(Not),1,0,f))
            update(d(i,0,0,f),d(i.getNextColor(Dup),1,0,f+1))
          for f in 2..<min(here(i).len(),maxFund-1):
            update(d(i,0,0,f),d(i.getNextColor(Add),1,0,f-1))
            update(d(i,0,0,f),d(i.getNextColor(Sub),1,0,f-1))
            update(d(i,0,0,f),d(i.getNextColor(Mul),1,0,f-1))
            update(d(i,0,0,f),d(i.getNextColor(Div),1,0,f-1))
            update(d(i,0,0,f),d(i.getNextColor(Mod),1,0,f-1))
  proc showPath(startKey:DPKey) =
    var key = startKey
    var colors = newSeq[int]()
    while not(key.nop == 0 and key.ord == 0 and key.fund == 0):
      colors &= key.color
      let nowDp = dp[key]
      key = nowDp.preKey
    colors &= key.color
    colors.reverse()
    var echoMat = newMatrix[PietColor](colors.len(),1)
    for i,color in colors: echoMat[i,0] = color.PietColor
    echo dp[startKey].val,":",colors.len()
    echo echoMat.toConsole()
    echo base.toConsole()
    echo echoMat.newGraph()[0].orderAndSizes.mapIt(it.order)
    echo orders
  var mins = newSeq[DPKey]()
  for progress in 0..<base.width:
    for nop in 0..progress:
      let ord = progress - nop
      if ord < orders.len(): continue
      let minIndex = toSeq(0..chromMax).mapIt(
        if dp[it][nop][ord].len() == 0 : EPS else:dp[it][nop][ord][0].val
        ).argmin()
      let minVal = dp[minIndex][nop][ord]
      if minVal.len() == 0 or minVal[0].val == EPS : continue
      mins &= (minIndex,nop,ord,0)
  for m in mins.sorted((a,b)=>dp[a].val - dp[b].val)[0..<min(1,mins.len())]:
    showPath(m)

proc quasiStegano1D*(orders:seq[OrderAndArgs],base:Matrix[PietColor]) =
  # ビームサーチでそれなりによいものを探す
  checkStegano1D(orders,base)
  const maxFrontierNum = 100
  # index == ord | N個の [PietMat,先頭{Color,DP,CC,Fund}]
  type Val = tuple[val:int,mat:Matrix[PietColor],x,y:int,dp:DP,cc:CC,fund:int]
  var fronts = newSeqWith(1,newSeq[Val]())
  block: # 最初は白以外
    let color = base[0,0]
    for i in 0..<chromMax:
      var initMat = newMatrix[PietColor](base.width,base.height)
      initMat.point((x,y) => -1)
      initMat[0,0] = i.PietColor
      fronts[0] &= (distance(color,i.PietColor),initMat,0,0,newDP(),newCC(),0)
  for progress in 0..<(base.width-1):
    var nexts = newSeqWith(min(fronts.len(),orders.len())+1,newSeq[Val]())
    for ord in 0..<fronts.len():
      let front = fronts[ord]
      if ord == orders.len():
        for f in front: nexts[ord] &= f
        continue
      let order = orders[ord]
      proc push(f:Val,nextColor,dx,dy,dOrd,dFund:int,dp:DP,cc:CC) =
        var next : Val = (f.val,f.mat.deepCopy(),f.x + dx,f.y + dy,dp,cc,f.fund+dFund)
        next.mat[next.x,next.y] = nextColor.PietColor
        next.val += distance(nextColor.PietColor,base[next.x,next.y])
        nexts[ord+dOrd] &= next
      proc pushAs1D(f:Val,nextColor,dOrd,dFund:int) =
        f.push(nextColor,1,0,dOrd,dFund,f.dp,f.cc)
      for f in front:
        let hereColor = f.mat[f.x,f.y]
        if f.fund == 0 and hereColor != chromMax: # 命令を進めた
          f.pushAs1D(hereColor.getNextColor(order.operation),1,0)
        # Nop (* -> 白)
        f.pushAs1D(chromMax,0,0)
        if hereColor == chromMax: # (白 -> *)
          for i in 0..<chromMax: f.pushAs1D(i,0,0)
        else: # Fund(白では詰めない)
          f.pushAs1D(hereColor.getNextColor(Push),0,1)
          if ord+1 < orders.len() and orders[ord+1].operation != Push:
            f.pushAs1D(hereColor,0,0) # 次がPushというせいでNopなどもできない!!
          if f.fund > 0:
            f.pushAs1D(hereColor.getNextColor(Pop),0,-1)
            f.pushAs1D(hereColor.getNextColor(Not),0,0)
            f.pushAs1D(hereColor.getNextColor(Dup),0,1)
          if f.fund > 1:
            f.pushAs1D(hereColor.getNextColor(Add),0,-1)
            f.pushAs1D(hereColor.getNextColor(Sub),0,-1)
            f.pushAs1D(hereColor.getNextColor(Mul),0,-1)
            f.pushAs1D(hereColor.getNextColor(Div),0,-1)
            f.pushAs1D(hereColor.getNextColor(Mod),0,-1)
    fronts = nexts.mapIt(it.sorted((a,b)=>a.val-b.val)[0..min(it.len(),maxFrontierNum)-1])
  block:
    let front = fronts[^1]
    echo "->{front[0].val}".fmt()
    echo front[0].mat.toConsole()
    echo base.toConsole()
    echo front[0].mat.newGraph()[0].orderAndSizes.mapIt(it.order)
    echo orders

proc quasiStegano2D*(orders:seq[OrderAndArgs],base:Matrix[PietColor],maxFrontierNum :int=500,maxFundLevel :int= 4,maxTrackBackOrderLen :int= 30) :Matrix[PietColor]=
  # stegano1Dの時と同じで1マス1マス進めていく方が探索範囲が広そう
  # * 偶然にも全く同じ画像が作られてしまうことがあるので,同じものがないかを確認してhashを取る必要がある
  doAssert base.width < int16.high and base.height < int16.high
  type
    Pos = tuple[x,y:int16] # 25:390MB -> 25:268MB # メモリが 2/3で済む(int8ではほぼ変化なし)
    # マスを増やすという操作のために今のブロックの位置配列を持っておく
    UsedInfo = tuple[used:bool,pos:Pos]
    BlockInfoObject = object
      # 有彩色以外では color以外の情報は参考にならないことに注意
      # -> deepcopy時に白や黒はサボれる
      endPos:EightDirection[UsedInfo]
      color:PietColor
      sameBlocks: seq[int] # ブロックサイズはここから取得できる
      sizeFix : bool # Pushしたのでこのサイズでなくてはならないというフラグ
    BlockInfo = ref BlockInfoObject
    NodeObject = object
      val,x,y:int
      mat:Matrix[BlockInfo]
      dp:DP
      cc:CC
      fund:Stack[int]
    Node = ref NodeObject not nil
  proc newBlockInfo(x,y:int,color:PietColor) : BlockInfo =
    # 新たに(隣接のない前提で)1マス追記
    new(result)
    let index = base.getI(x,y)
    result.endPos = newEightDirection((false,(x.int16,y.int16)))
    result.color = color
    result.sameBlocks = @[index]
    result.sizeFix = false
  let whiteBlockInfo = newBlockInfo(-1,-1,WhiteNumber)
  let blackBlockInfo = newBlockInfo(-1,-1,BlackNumber)
  proc hashing(mat:Matrix[BlockInfo]) : Hash =
    for d in mat.data:
      result = result !& hash(if d == nil : -1 else: d.color)
    result = !$result
  proc deepCopy(x:BlockInfo): BlockInfo =
    # コピーコンストラクタはおそすぎるので直代入
    new(result)
    # result[] = x[]
    result.endPos = x.endPos
    result.color = x.color
    result.sameBlocks = x.sameBlocks
    result.sizeFix = x.sizeFix

  proc toConsole(self:Matrix[BlockInfo]) : string =
    var mat = newMatrix[PietColor](self.width,self.height)
    for x in 0..<self.width:
      for y in 0..<self.height:
        mat[x,y] = if self[x,y] == nil : -1  else: self[x,y].color
    return mat.toConsole()
  proc toPietColorMap(self:Matrix[BlockInfo]) : Matrix[PietColor] =
    result = newMatrix[PietColor](self.width,self.height)
    for x in 0..<self.width:
      for y in 0..<self.height:
        if self[x,y] == nil : result[x,y] = -1
        else: result[x,y] = self[x,y].color
  proc newNode(val,x,y:int,mat:Matrix[BlockInfo],dp:DP,cc:CC,fund:Stack[int]) : Node =
    new(result)
    result.val = val
    result.x = x
    result.y = y
    result.mat = mat
    result.dp = dp
    result.cc = cc
    result.fund = fund
  proc isIn(x,y:int):bool = x >= 0 and y >= 0 and x < base.width and y < base.height
  proc checkAdjasts(mat:Matrix[BlockInfo],x,y:int,color:PietColor) : seq[BlockInfo] =
    # color と同じ色で隣接しているものを取得
    result = @[]
    for dxdy in dxdys:
      let (dx,dy) = dxdy
      let (nx,ny) = (x + dx,y + dy)
      if not isIn(nx,ny) : continue
      if mat[nx,ny] == nil : continue
      if mat[nx,ny].color != color : continue
      if mat[nx,ny] in result: continue # 大丈夫...?
      result &= mat[nx,ny]
  proc updateVal(val:var int,x,y:int,color:PietColor) =
    val += distance(color,base[x,y])
    # 色に元画像の出現割合に応じて重み付けするとお得?
    # val += (distance(color,base[x,y]).float * weights[color.int]).int
  proc updateMat(mat:var Matrix[BlockInfo],x,y:int,color:PietColor) :bool =
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
    doAssert mat[x,y] == nil
    if color == WhiteNumber:
      mat[x,y] = whiteBlockInfo
      return true
    if color == BlackNumber:
      mat[x,y] = blackBlockInfo
      return true
    let adjasts = mat.checkAdjasts(x,y,color)
    if adjasts.len() == 0 : # 新規
      mat[x,y] = newBlockInfo(x,y,color)
      return true
    for adjast in adjasts: # そもそも全部結合していいやつかチェック
      if adjast.sizeFix : return false
    # とりあえず自身をコピーした0番に結合
    let zeroBlock = adjasts[0].deepCopy()
    zeroBlock.sameBlocks &= base.getI(x,y)
    if not zeroBlock.endPos.canUpdateEndPos(x,y) : return false
    template connect(adjast) = # コピーが作成されているゼロ番に結合
      let newBlock = adjast.deepCopy()
      # チェック
      for b in zeroBlock.sameBlocks:
        let (bx,by) = base.getXY(b)
        if not newBlock.endPos.canUpdateEndPos(bx,by) : return false
      for b in newBlock.sameBlocks:
        let (bx,by) = base.getXY(b)
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
  proc update(mat:var Matrix[BlockInfo],val:var int,x,y:int,color:PietColor) : bool =
    val.updateVal(x,y,color)
    return mat.updateMat(x,y,color)
  proc getNextPos(endPos:EightDirection[UsedInfo],dp:DP,cc:CC) : tuple[x,y:int] =
    let (x,y) = endPos[cc,dp].pos
    let (dX,dY) = dp.getdXdY()
    return (x + dX,y + dY)
  proc searchNotVisited(mat:Matrix[BlockInfo],x,y:int,startDP:DP,startCC:CC) : tuple[ok:bool,dp:DP,cc:CC]=
    # 次に行ったことのない壁ではない場所にいけるかどうかだけチェック(更新はしない)
    doAssert mat[x,y] != nil and mat[x,y].color < chromMax
    var dp = startDP
    var cc = startCC
    result = (false,dp,cc)
    for i in 0..<8:
      let used = mat[x,y].endPos[cc,dp].used
      let (nX,nY) = mat[x,y].endPos.getNextPos(dp,cc)
      if not isIn(nX,nY) or (mat[nX,nY] != nil and mat[nX,nY].color == BlackNumber):
        if i mod 2 == 0 : cc.toggle()
        else: dp.toggle(1)
        continue
      if used : return
      return (true,dp,cc)
    return

  proc updateUsingNextPos(mat:var Matrix[BlockInfo],x,y:int,dp:DP,cc:CC) : tuple[x,y:int] =
    # 使用済みに変更して全部更新してから返却
    doAssert( not mat[x,y].endPos[cc,dp].used )
    let newBlock = mat[x,y].deepCopy()
    newBlock.endPos[cc,dp] = (true,newBlock.endPos[cc,dp].pos)
    for b in newBlock.sameBlocks : mat.data[b] = newBlock
    return mat[x,y].endPos.getNextPos(dp,cc)

  proc toNextState(mat:var Matrix[BlockInfo],x,y:int,startDP:DP,startCC:CC) : tuple[ok:bool,x,y:int,dp:DP,cc:CC]=
    # 使用したことのない場所で新たに行けるならそれを返却
    doAssert mat[x,y] != nil and mat[x,y].color < chromMax
    template failed() : untyped = (false,x,y,startDP,startCC)
    var dp = startDP
    var cc = startCC
    var usedDir : EightDirection[bool]
    for i in 0..<8:
      let used = mat[x,y].endPos[cc,dp].used
      let (nX,nY) = mat[x,y].endPos.getNextPos(dp,cc)
      usedDir[cc,dp] = true
      if not isIn(nX,nY) or (mat[nX,nY] != nil and mat[nX,nY].color == BlackNumber):
        if i mod 2 == 0 : cc.toggle()
        else: dp.toggle(1)
        continue
      if used : return failed
      let newBlock = mat[x,y].deepCopy()
      for ccdp in allCCDP():
        let (ncc,ndp) = ccdp
        if not usedDir[ncc,ndp] : continue
        newBlock.endPos[ncc,ndp] = (true,newBlock.endPos[ncc,ndp].pos)
      for b in newBlock.sameBlocks : mat.data[b] = newBlock
      return (true,nX,nY,dp,cc)
    return failed


  var fronts = newSeqWith(orders.len()+1,newSeqWith(maxFundLevel,newSeq[Node]()))
  var completedMin = EPS
  block: # 最初の1マスは白以外
    for c in 0..<chromMax:
      var initMat = newMatrix[BlockInfo](base.width,base.height) # 全てnil
      var val = 0
      if not initMat.update(val,0,0,c.PietColor) : quit("yabee")
      fronts[0][0] &= newNode(val,0,0,initMat,newDP(),newCC(),newStack[int]())
  for progress in 0..<(base.width * base.height):
    # top()が一番雑魚
    var nexts = newSeqWith( orders.len()+1,
      newSeqWith(maxFundLevel,newBinaryHeap[Node](proc(x,y:Node):int= y.val - x.val)))
    var stored = newSeqWith( orders.len()+1,
      newSeqWith(maxFundLevel,initSet[Hash]()))
    let maxNonNilFrontIndex = toSeq(0..<fronts.len()).filterIt(fronts[it].mapIt(it.len()).sum() > 0).max()
    # 命令を実行できる人の方が偉いので強い重みをつける()
    let maxFunds = toSeq(0..<maxFundLevel).mapIt(maxFrontierNum div (1 + 4 * it))
    proc getMaxFunds(fundLevel,ord:int):int =
      let trackbacked = (ord - maxNonNilFrontIndex + maxTrackBackOrderLen).float /  maxTrackBackOrderLen.float
      return int(maxFunds[fundLevel].float * max(1.0,trackbacked))
    proc storedWorstVal(fundLevel,ord:int):int =
      if fundLevel >= maxFundLevel : return -1 # 越えたときも-1で簡易的に弾く
      if nexts[ord][fundLevel].len() < getMaxFunds(fundLevel,ord) : return min(EPS,completedMin)
      if nexts[ord][fundLevel].len() == 0 : return min(EPS,completedMin)
      return min(nexts[ord][fundLevel].top().val,completedMin)
    proc store(node:Node,ord:int) =
      let fundLevel = node.fund.len()
      if fundLevel >= maxFundLevel : return
      if storedWorstVal(fundLevel,ord) <= node.val : return
      let hashing = node.mat.hashing
      if hashing in stored[ord][fundLevel]: return
      nexts[ord][fundLevel].push(node)
      stored[ord][fundLevel].incl(hashing)
      if nexts[ord][fundLevel].len() > getMaxFunds(fundLevel,ord)  :
        # exclしなくてもいいかな
        discard nexts[ord][fundLevel].pop()
    proc getFront(ord:int) : seq[Node] =
      result = @[]
      for fr in fronts[ord]:
        for f in fr:
          result &= f
    for ord in 0..orders.len():
      # if ord < maxNonNilFrontIndex - maxTrackBackOrderLen : continue
      let front = getFront(ord)
      if ord == orders.len():
        if front.len() > 0 : completedMin = front.mapIt(it.val).max() + 1
        for f in front:
          f.store(ord)
          # nexts[ord][f.fund.len()].push(f)
        if front.len() > 0 : completedMin = front.mapIt(it.val).min()
        continue
      let order = orders[ord]
      proc tryUpdate(f:Node,x,y:int,color:PietColor,dOrd,dFund:int) : tuple[ok:bool,val:int,mat:Matrix[BlockInfo]] =
        template mistaken() : untyped = (false,-1,newMatrix[BlockInfo](0,0))
        block: # 一回試してみる
          var tmpVal = f.val
          updateVal(tmpVal,x,y,color)
          if storedWorstVal(f.fund.len()+dFund,ord + dOrd) <= tmpVal : return mistaken
        var newMat = f.mat.deepCopy()
        var newVal = f.val
        if not newMat.update(newVal,x,y,color) : return mistaken
        return (true,newVal,newMat)
      proc tryUpdateNotVisited(f:Node,color:PietColor,dOrd,dFund:int,onlyNil:bool = false,onlySameColor:bool=false,onlyNotUsedCCDP:bool=false) : bool =
        # 一回試してみる(+nilなら更新した時のコストもチェック)
        let (ok,dp,cc) = f.mat.searchNotVisited(f.x,f.y,f.dp,f.cc)
        if not ok : return false
        let (nx,ny) = f.mat[f.x,f.y].endPos.getNextPos(dp,cc)
        if f.mat[nx,ny] == nil:
          var tmpVal = f.val
          updateVal(tmpVal,nx,ny,color)
          if storedWorstVal(f.fund.len()+dFund,ord + dOrd) <= tmpVal : return false
          return true
        # そもそも空いて無いと駄目
        if onlyNil : return false
        # 交差した時だと思うけれども同じ色しか駄目
        if onlySameColor and f.mat[nx,ny].color != color : return false
        # 交差した時に,ループに陥らないよう,今のままのdpccで行けるかチェック
        if onlyNotUsedCCDP and f.mat[nx,ny].endPos[cc,dp].used : return false
        return true

      proc checkTerminate(f:Node) =
        var newMat = f.mat.deepCopy()
        var dp = f.dp
        var cc = f.cc
        var newVal = f.val
        for i in 0..<8:
          let (nX,nY) = newMat.updateUsingNextPos(f.x,f.y,dp,cc)
          if isIn(nX,nY):
            if newMat[nX,nY] == nil :
              if not newMat.update(newVal,nX,nY,BlackNumber) : return
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
            if not isIn(nx,ny) : continue
            let ext = f.mat[nx,ny]
            if ext != nil : continue
            let (ok,newVal,newMat) = f.tryUpdate(nx,ny,here.color,0,0)
            if not ok : continue
            let nextNode = newNode(newVal,nx,ny,newMat,f.dp,f.cc,f.fund.deepCopy())
            nextNode.store(ord)
            if order.operation == Terminate: nextNode.checkTerminate()

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
        if not newMat.update(newVal,nx,ny,color) : return
        var nextNode = newNode(newVal,nx,ny,newMat,dp,cc,f.fund.deepCopy())
        if order == Push : newMat[f.x,f.y].sizeFix = true
        if not nextNode.callback(): return
        nextNode.store(ord+dOrd)

      proc doOrder(f:Node) =
        let here = f.mat[f.x,f.y]
        if here.color >= chromMax : return
        if f.fund.len() > 0 : return
        if order.operation == Terminate: return
        if order.operation == Push and order.args[0].parseInt() != here.sameBlocks.len() : return
        f.decide(order.operation,1,0)
      proc goWhite(f:Node) =
        let here = f.mat[f.x,f.y]
        if here.color == WhiteNumber:
          let (dx,dy) = f.dp.getdXdY()
          let (nx,ny) = (f.x+dx,f.y+dy)
          if not isIn(nx,ny) : return
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
          if not newMat.update(newVal,nx,ny,WhiteNumber) : return
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
        if not newMat.update(newVal,nx,ny,BlackNumber) : return
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

      for f in front:
        f.extendBlock()
        f.doOrder()
        f.pushBlack()
        f.goWhite()
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

        #   # 6. Terminate -> 今のブロックの位置配列から増やしまくるのを20個程度して終わらせる
    let nextItems = (proc():seq[seq[seq[Node]]]=
      result = newSeqWith(orders.len()+1,newSeqWith(maxFundLevel,newSeq[Node]()))
      for i in 0..<nexts.len():
        var next = nexts[i]
        for j in 0..<next.len():
          result[i][j] &= nexts[i][j].items()
    )()
    fronts = nextItems.mapIt(it.mapIt(it.sorted((a,b)=>a.val-b.val)))
    let maxes =  fronts.mapIt(it.mapIt(it.len()).sum())
    for i in 0..<fronts.len():
      let front = fronts[^(1+i)]
      if front.len() == 0 : continue
      if front[0].len() == 0: continue
      # 最後のプロセス省略
      for j in 0..<0.min(front[0].len()):
        # echo fronts.mapIt(it.mapIt(it.len()))
        # echo stored.mapIt(it.mapIt(it.card).sum())
        # echo nextItems.mapIt(it.mapIt(it.len()))
        # echo nextItems.mapIt(it.mapIt(it.mapIt(it.val)).filterIt(it.len() > 0).mapIt([it.max(),it.min()]))
        # echo front[0].mat.newGraph().mapIt(it.orderAndSizes.mapIt(it.order))
        # stdout.write progress;stdout.flushFile
        echo maxes
        echo front[0][j].mat.toConsole(),front[0][0].val,"\n"
        # echo front[0][j].mat.toPietColorMap().newGraph().mapIt(it.orderAndSizes.mapIt(it.order))
        echo "progress: ",progress
        echo "memory  :" ,getTotalMem() div 1024 div 1024,"MB"
      break
    if maxes[^1] > 0 and maxes[^2] == 0 and maxes[^3] == 0 :
      break
  block: # 成果
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
              if not isIn(nx,ny) : continue
              if initMat[nx,ny] == nil : continue
              if initMat[nx,ny].color == color : return true
            return false
          )(f)
          if color < chromMax and adjast : continue
          if not f.mat.update(f.val,x,y,color): quit("yabeeyo")
      # 隣接しているので一番近い色を埋める
      for x in 0..<f.mat.width:
        for y in 0..<f.mat.height:
          if f.mat[x,y] != nil: continue
          let color = base[x,y]
          var newMat = f.mat.deepCopy()
          var newVal = f.val
          if newMat.update(newVal,x,y,color) :
            f.mat = newMat
            f.val = newVal
            continue
          type Try = tuple[success:bool,mat:Matrix[BlockInfo],val:int]
          var tries = newSeq[Try]()
          for c in 0..<chromMax:
            var success = false
            var newMat = f.mat.deepCopy()
            var newVal = f.val
            if newMat.update(newVal,x,y,c.PietColor) :
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
proc makeRandomOrders(length:int):seq[OrderAndArgs] =
  randomize()
  proc getValidOrders():seq[Order] =
    result = @[]
    for oo in orderBlock:
      for o in oo:
        if o notin [ErrorOrder,Terminate,Pointer,Switch] :
          result &= o
  result = @[]
  let orderlist = getValidOrders()
  for _ in 0..<length:
    let order = orderlist[rand(orderlist.len()-1)]
    let args = if order == Push : @["1"] else: @[]
    result &= (Operation,order,args)
  result &= (MoveTerminate,Terminate,@[])

proc makeRandomPietColorMatrix*(width,height:int) : Matrix[PietColor] =
  randomize()
  result = newMatrix[PietColor](width,height)
  for x in 0..<width:
    for y in 0..<height:
      result[x,y] = rand(maxColorNumber).PietColor

proc makeLocalRandomPietColorMatrix*(width,height:int) : Matrix[PietColor] =
  randomize()
  result = newMatrix[PietColor](width,height)
  const same = 5
  for x in 0..<width:
    for y in 0..<height:
      result[x,y] = rand(maxColorNumber).PietColor
      if rand(1) == 0:
        if rand(10) > same and x > 0:
          result[x,y] = result[x-1,y]
        if rand(10) > same and y > 0:
          result[x,y] = result[x,y-1]
      else:
        if rand(10) > same and y > 0:
          result[x,y] = result[x,y-1]
        if rand(10) > same and x > 0:
          result[x,y] = result[x-1,y]

if isMainModule:
  echo getTotalMem() div 1024 div 1024
  echo getOccupiedMem() div 1024 div 1024
  echo getFreeMem() div 1024 div 1024

  if false:
    let orders = makeRandomOrders(20)
    let baseImg = makeRandomPietColorMatrix(64,1)
    stegano1D(orders,baseImg)
    quasiStegano1D(orders,baseImg)
  if false:
    let orders = makeRandomOrders(20)
    let baseImg = makeLocalRandomPietColorMatrix(12,12)
    echo baseImg.toConsole()
    discard quasiStegano2D(orders,baseImg,400).toConsole()
  if commandLineParams().len() > 0:
    let baseImg = commandLineParams()[0].newPietMap().pietColorMap
    proc getOrders():seq[OrderAndArgs] =
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
      for i in 0..<1:
        for oa in orders:
          let (order,args) = oa
          result &= (Operation,order,args)
      result &= (MoveTerminate,Terminate,@[])
    let orders = getOrders()
    # let orders = makeRandomOrders((baseImg.width.float * baseImg.height.float * 0.1).int)
    echo orders
    echo baseImg.toConsole()
    var sw = newStopWatch()
    sw.start()
    let stegano = quasiStegano2D(orders,baseImg,20,6) # 720
    sw.stop()
    echo sw
    stegano.save("./piet.png",codelSize=10)