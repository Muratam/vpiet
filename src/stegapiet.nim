import common
import pietbase
import pietmap
import pietize
import curse
import makegraph
import sets
import colordiff
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
            f.pushAs1D(hereColor,0,0) # WARN: 次がPushというせいでNopなどもできない!!
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

proc quasiStegano2D*(orders:seq[OrderAndArgs],base:Matrix[PietColor],maxFrontierNum :int=500) :Matrix[PietColor]=
  # 以前の実装ではマスのサイズが不定なので微妙にムラがあるように見える
  # 埋めたブロック数がほぼ(交差のせい)同じ者同士で比較したほうがよいにきまっている
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
      size:int
      color:PietColor
      sameBlocks: seq[Pos]
      sizeFix : bool # Pushしたのでこのサイズでなくてはならない
    BlockInfo = ref BlockInfoObject
    NodeObject = object
      val,x,y:int
      mat:Matrix[BlockInfo]
      dp:DP
      cc:CC
      fund:Stack[int]
    Node = ref NodeObject not nil
  proc deepBICopy(mat:Matrix[BlockInfo]) : Matrix[BlockInfo] =
    proc box[T](x:T): ref T =
      new(result)
      result[] = x
    result = newMatrix[BlockInfo](mat.width,mat.height)
    for x in 0..<mat.width:
      for y in 0..<mat.height:
        let here = mat[x,y]
        if here == nil : continue
        if here.color >= chromMax :
          result[x,y] = mat[x,y]
          continue
        let firstBlock = here.sameBlocks[0]
        if x == firstBlock.x and y == firstBlock.y :
          result[x,y] = box(here[])
    for x in 0..<mat.width:
      for y in 0..<mat.height:
        let here = mat[x,y]
        if here == nil : continue
        if here.color >= chromMax : continue
        let firstBlock = here.sameBlocks[0]
        if x == firstBlock.x and y == firstBlock.y : continue
        result[x,y] = result[firstBlock.x,firstBlock.y]



  proc toConsole(self:Matrix[BlockInfo]) : string =
    var mat = newMatrix[PietColor](self.width,self.height)
    for x in 0..<self.width:
      for y in 0..<self.height:
        mat[x,y] = if self[x,y] == nil : -1  else: self[x,y].color
    return mat.toConsole()
  proc newBlockInfo(x,y:int,color:PietColor) : BlockInfo =
    # 新たに(隣接のない前提で)1マス追記
    new(result)
    let pos :Pos= (x.int16,y.int16)
    result.endPos = newEightDirection((false,pos))
    result.size = 1
    result.color = color
    result.sameBlocks = @[pos]
    result.sizeFix = false
  let whiteBlockInfo = newBlockInfo(-1,-1,WhiteNumber)
  let blackBlockInfo = newBlockInfo(-1,-1,BlackNumber)
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
  # let weights = (proc():seq[float] =
  #   # 重み(1.0 ~ 2.0)
  #   var weights = newSeqWith(maxColorNumber+1,base.width * base.height)
  #   for x in 0..<base.width:
  #     for y in 0..<base.height:
  #       weights[base[x,y]] += 1
  #   return weights.mapIt((base.width*base.height).float * 2.0 / it.float )
  # )()
  proc updateVal(val:var int,x,y:int,color:PietColor) =
    val += distance(color,base[x,y])
    # 色に元画像の出現割合に応じて重み付けするとお得?
    # val += (distance(color,base[x,y]).float * weights[color.int]).int
  proc updateMat(mat:var Matrix[BlockInfo],x,y:int,color:PietColor) :bool =
    proc updateEndPos(e:var EightDirection[UsedInfo],x,y:int) : bool =
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
    doAssert mat[x,y] == nil
    if color == WhiteNumber:
      mat[x,y] = whiteBlockInfo
      return true
    if color == BlackNumber:
      mat[x,y] = blackBlockInfo
      return true
    let adjasts = mat.checkAdjasts(x,y,color)
    case adjasts.len():
    of 0: # 新規
      mat[x,y] = newBlockInfo(x,y,color)
      return true
    else:
      # とりあえず0番に結合
      mat[x,y] = adjasts[0]
      mat[x,y].sameBlocks &= (x.int16,y.int16)
      mat[x,y].size += 1
      for adjast in adjasts: # ついでに全部結合していいやつかチェック
        if adjast.sizeFix : return false
      if not mat[x,y].endPos.updateEndPos(x,y) : return false
    template connect(i0,i1) =
      # 結合時のテスト
      for b in adjasts[i0].sameBlocks:
        if adjasts[i1].endPos.updateEndPos(b.x,b.y) : return false
      for b in adjasts[i1].sameBlocks:
        if adjasts[i0].endPos.updateEndPos(b.x,b.y) : return false
      for b in adjasts[i1].sameBlocks:
        mat[b.x,b.y] = adjasts[i0]
        mat[x,y].size += 1
        mat[x,y].sameBlocks &= (b.x,b.y)
        doAssert x != b.x or y != b.y

    case adjasts.len():
    of 0: return true
    of 1: return true
    of 2:
      connect(0,1)
      return true
    of 3:
      # 0 <- 1
      connect(0,1)
      connect(0,2)
      return true
    of 4:
      connect(0,1)
      connect(0,2)
      connect(0,3)
      return true
    else:
      return false
  proc update(mat:var Matrix[BlockInfo],val:var int,x,y:int,color:PietColor) : bool =
    val.updateVal(x,y,color)
    return mat.updateMat(x,y,color)

  proc getNextPos(endPos:EightDirection[UsedInfo],dp:DP,cc:CC) : tuple[x,y:int] =
    let (x,y) = endPos[cc,dp].pos
    let (dX,dY) = dp.getdXdY()
    return (x + dX,y + dY)

  proc useNextPos(endPos:var EightDirection[UsedInfo],dp:DP,cc:CC) : tuple[x,y:int] =
    endPos[cc,dp] = (true,endPos[cc,dp].pos)
    return endPos.getNextPos(dp,cc)

  proc searchNotVisited(mat:var Matrix[BlockInfo],x,y:int,startDP:DP,startCC:CC) : tuple[ok:bool,dp:DP,cc:CC]=
    # 次に行ったことのない壁ではない場所にいけるなら ok
    doAssert mat[x,y] != nil and mat[x,y].color < chromMax
    var dp = startDP
    var cc = startCC
    result = (false,dp,cc)
    for i in 0..<8:
      let used = mat[x,y].endPos[cc,dp].used
      let (nX,nY) = mat[x,y].endPos.useNextPos(dp,cc)
      if not isIn(nX,nY) or (mat[nX,nY] != nil and mat[nX,nY].color == BlackNumber):
        if i mod 2 == 0 : cc.toggle()
        else: dp.toggle(1)
        continue
      if used : return
      return (true,dp,cc)
    return
  const maxFundLevel = 4
  let maxFunds = toSeq(0..<maxFundLevel).mapIt(maxFrontierNum div (1 + it))
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
    proc storedWorstVal(fundLevel:int,ord:int):int =
      if nexts[ord][fundLevel].len() < maxFunds[fundLevel] : return min(EPS,completedMin)
      if nexts[ord][fundLevel].len() == 0 : return min(EPS,completedMin)
      return min(nexts[ord][fundLevel].top().val,completedMin)
    proc store(node:Node,ord:int) =
      let fundLevel = node.fund.len()
      if fundLevel >= maxFundLevel : return
      if storedWorstVal(fundLevel,ord) <= node.val : return
      nexts[ord][fundLevel].push(node)
      if nexts[ord][fundLevel].len() > maxFunds[fundLevel] :
        discard nexts[ord][fundLevel].pop()
    proc getFront(ord:int) : seq[Node] =
      result = @[]
      for fr in fronts[ord]:
        for f in fr:
          result &= f

    for ord in 0..orders.len():
      let front = getFront(ord)
      if ord == orders.len():
        if front.len() > 0 : completedMin = front.mapIt(it.val).max() + 1
        for f in front:
          f.store(ord)
          # nexts[ord][f.fund.len()].push(f)
        if front.len() > 0 : completedMin = front.mapIt(it.val).min()
        continue
      let order = orders[ord]
      proc extendBlock(f:Node) =
        let here = f.mat[f.x,f.y]
        if here.color >= chromMax : return
        for b in here.sameBlocks:
          for dxdy in dxdys:
            let (dx,dy) = dxdy
            let (nx,ny) = (b.x + dx,b.y + dy)
            if not isIn(nx,ny) : continue
            let ext = f.mat[nx,ny]
            if ext != nil : continue
            var newMat = f.mat.deepBICopy()
            var newVal = f.val
            if not newMat.update(newVal,nx,ny,here.color) : continue
            let nextNode = newNode(newVal,nx,ny,newMat,f.dp,f.cc,f.fund.deepCopy())
            nextNode.store(ord)
      proc decide(f:Node,order:Order,dOrd:int,callback:proc(_:var Node):bool = (proc(_:var Node):bool=true)) =
        let here = f.mat[f.x,f.y]
        let color = here.color.getNextColor(order).PietColor
        var newMat = f.mat.deepBICopy()
        let (ok,dp,cc) = newMat.searchNotVisited(f.x,f.y,f.dp,f.cc)
        if not ok : return
        let (nx,ny) = newMat[f.x,f.y].endPos.useNextPos(dp,cc)
        if newMat[nx,ny] != nil :
          let next = newMat[nx,ny]
          if next.color != color : return
          # 交差した時は,ループに陥らないよう,今のままのdpccで行けるかチェック
          if next.endPos[cc,dp].used : return
          var nextNode = newNode(f.val,nx,ny,newMat,dp,cc,f.fund.deepCopy())
          if not nextNode.callback(): return
          nextNode.store(ord+dOrd)
          return
        var newVal = f.val
        if not newMat.update(newVal,nx,ny,color) : return
        var nextNode = newNode(newVal,nx,ny,newMat,dp,cc,f.fund.deepCopy())
        if order == Push :
          newMat[f.x,f.y].sizeFix = true
        if not nextNode.callback(): return
        nextNode.store(ord+dOrd)
      proc doOrder(f:Node) =
        let here = f.mat[f.x,f.y]
        if here.color >= chromMax : return
        if order.operation == Terminate:
          var newMat = f.mat.deepBICopy()
          var dp = f.dp
          var cc = f.cc
          var newVal = f.val
          for i in 0..<8:
            let (nX,nY) = newMat[f.x,f.y].endPos.useNextPos(dp,cc)
            if isIn(nX,nY):
              if newMat[nX,nY] == nil :
                if not newMat.update(newVal,nX,nY,BlackNumber) : return
              elif newMat[nX,nY].color != BlackNumber: return
            if i mod 2 == 0 : cc.toggle()
            else: dp.toggle(1)
          let nextNode = newNode(newVal,f.x,f.y,newMat,dp,cc,f.fund.deepCopy())
          nextNode.store(ord+1)
          return
        if f.fund.len() > 0 : return
        if order.operation == Push and order.args[0].parseInt() != here.size : return
        f.decide(order.operation,1)
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
              let nextNode = newNode(f.val,nx,ny,f.mat.deepBICopy(),f.dp,f.cc,f.fund.deepCopy())
              nextNode.store(ord)
              return
            # 交差した時は,ループに陥らないよう,今のままのdpccで行けるかチェック
            if next.endPos[f.cc,f.dp].used : return
            var nextNode = newNode(f.val,nx,ny,f.mat.deepBICopy(),f.dp,f.cc,f.fund.deepCopy())
            nextNode.store(ord)
            return
          doAssert chromMax == WhiteNumber
          for c in 0..chromMax:
            var newMat = f.mat.deepBICopy()
            var newVal = f.val
            if not newMat.update(newVal,nx,ny,c.PietColor) : continue
            let nextNode = newNode(newVal,nx,ny,newMat,f.dp,f.cc,f.fund.deepCopy())
            nextNode.store(ord)
          return
        else:
          var newMat = f.mat.deepBICopy()
          let (ok,dp,cc) = newMat.searchNotVisited(f.x,f.y,f.dp,f.cc)
          if not ok : return
          let (nx,ny) = newMat[f.x,f.y].endPos.useNextPos(dp,cc)
          var newVal = f.val
          if newMat[nx,ny] != nil : return
          if not newMat.update(newVal,nx,ny,WhiteNumber) : return
          let nextNode = newNode(newVal,nx,ny,newMat,dp,cc,f.fund.deepCopy())
          nextNode.store(ord)
      proc pushBlack(f:Node) =
        let here = f.mat[f.x,f.y]
        if here.color >= chromMax : return # 白で壁にぶつからないように
        var newMat = f.mat.deepBICopy()
        let (ok,dp,cc) = newMat.searchNotVisited(f.x,f.y,f.dp,f.cc)
        if not ok : return
        let (nx,ny) = newMat[f.x,f.y].endPos.useNextPos(dp,cc)
        var newVal = f.val
        if newMat[nx,ny] != nil : return
        if not newMat.update(newVal,nx,ny,BlackNumber) : return
        let nextNode = newNode(newVal,f.x,f.y,newMat,dp,cc,f.fund.deepCopy())
        nextNode.store(ord)
      template doFundIt(f:Node,order:Order,operation:untyped) : untyped =
        (proc =
          let here = f.mat[f.x,f.y]
          if here.color >= chromMax : return
          f.decide(order,0, proc(node:var Node) :bool=
            let it{.inject.} = node # ref なのであとで代入すればいいよね
            operation
            node = it
            return true)
        )()


      for i,f in front:
        f.extendBlock()
        f.doOrder()
        f.pushBlack()
        f.goWhite()
        f.doFundIt(Push): it.fund.push(it.mat[it.x,it.y].size)
        if f.fund.len() > 0:
          f.doFundIt(Pop): discard it.fund.pop()
          f.doFundIt(Pointer): it.dp.toggle(it.fund.pop())
          f.doFundIt(Switch):
            if it.fund.pop() mod 2 == 1 : it.cc.toggle()
          f.doFundIt(Not) : it.fund.push(if it.fund.pop() == 0: 1 else: 0)
          f.doFundIt(Dup) : it.fund.push(it.fund.top())
        if f.fund.len() > 1:
          f.doFundIt(Add) :
            let top = it.fund.pop()
            let next = it.fund.pop()
            it.fund.push(next + top)
          f.doFundIt(Sub) :
            let top = it.fund.pop()
            let next = it.fund.pop()
            it.fund.push(next - top)
          f.doFundIt(Mul) :
            let top = it.fund.pop()
            let next = it.fund.pop()
            it.fund.push(next * top)
          f.doFundIt(Div) :
            let top = it.fund.pop()
            let next = it.fund.pop()
            if top == 0 : return false
            it.fund.push(next div top)
          f.doFundIt(Mod) :
            let top = it.fund.pop()
            let next = it.fund.pop()
            if top == 0 : return false
            it.fund.push(next mod top)
          f.doFundIt(Greater) :
            let top = it.fund.pop()
            let next = it.fund.pop()
            it.fund.push(if next > top : 1 else:0)
        #   # 6. Terminate -> 今のブロックの位置配列から増やしまくるのを20個程度して終わらせる
    let nextItems = (proc():seq[seq[seq[Node]]]=
      result = newSeqWith(orders.len()+1,newSeqWith(maxFundLevel,newSeq[Node]()))
      for i in 0..<nexts.len():
        var next = nexts[i]
        for j in 0..<next.len():
          result[i][j] &= nexts[i][j].items()
    )()
    fronts = nextItems.mapIt(it.mapIt(it.sorted((a,b)=>a.val-b.val)))
    for i in 0..<fronts.len():
      let front = fronts[^(1+i)]
      if front.len() == 0 : continue
      # 最後のプロセス省略
      if front[0].len() > 0:
        echo front[0][0].mat.toConsole(),front[0][0].val,"\n"
        break
      # echo nextItems.mapIt(it.mapIt(it.len()))
      # echo nextItems.mapIt(it.mapIt(it.mapIt(it.val)).filterIt(it.len() > 0).mapIt([it.max(),it.min()]))
      # echo front[0].mat.newGraph().mapIt(it.orderAndSizes.mapIt(it.order))
      # stdout.write progress;stdout.flushFile
    let maxes =  fronts.mapIt(it.mapIt(it.len()).max())
    echo "progress: ",progress
    echo "memory  :" ,getTotalMem() div 1024 div 1024,"MB"
    if progress > orders.len() * 3:  break # WARN: GC...
    echo maxes
    if maxes[^1] > 0 and maxes[^2] == 0 and maxes[^3] == 0 :
      break
  block: # 成果
    var front = fronts[^1][0]
    proc embedNotdecided(f:var Node) =
      # どこにも隣接していないやつを埋める
      for x in 0..<f.mat.width:
        for y in 0..<f.mat.height:
          if f.mat[x,y] != nil: continue
          let color = base[x,y]
          let adjast = (proc(f:var Node) :bool =
            for dxdy in dxdys:
              let (dx,dy) = dxdy
              let (nx,ny) = (x+dx,y+dy)
              if not isIn(nx,ny) : continue
              if f.mat[nx,ny] == nil : continue
              if f.mat[nx,ny].color == color : return true
            return false
          )(f)
          if color <= chromMax and adjast : continue
          if not f.mat.update(f.val,x,y,color): quit("yabeeyo")
      # 隣接しているので一番近い色を埋める
      for x in 0..<f.mat.width:
        for y in 0..<f.mat.height:
          if f.mat[x,y] != nil: continue
          let color = base[x,y]
          var newMat = f.mat.deepBICopy()
          var newVal = f.val
          if newMat.update(newVal,x,y,color) :
            f.mat = newMat
            f.val = newVal
            continue
          type Try = tuple[success:bool,mat:Matrix[BlockInfo],val:int]
          var tries = newSeq[Try]()
          for c in 0..<chromMax:
            var success = false
            var newMat = f.mat.deepBICopy()
            var newVal = f.val
            if newMat.update(newVal,x,y,c.PietColor) :
              success = true
            tries &= (success,newMat,newVal)
          tries = tries.filterIt(it.success).sorted((a,b)=> a.val - b.val)
          f.mat = tries[0].mat
          f.val = tries[0].val

    proc toPietColorMap(self:Matrix[BlockInfo]) : Matrix[PietColor] =
      result = newMatrix[PietColor](self.width,self.height)
      for x in 0..<self.width:
        for y in 0..<self.height:
          if self[x,y] == nil : result[x,y] = -1
          else: result[x,y] = self[x,y].color

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
    let mats = front.mapIt(it.mat.deepBICopy())
    let index = findEmbeddedMinIndex()
    result = front[index].mat.toPietColorMap()
    echo "result: before\n",mats[index].toPietColorMap().toConsole()
    echo "result :\n",result.toConsole(),front[index].val
    echo "base   :\n",base.toConsole()
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
      for oa in orders:
        let (order,args) = oa
        result &= (Operation,order,args)
      result &= (MoveTerminate,Terminate,@[])
    let orders = getOrders()
    # let orders = makeRandomOrders((baseImg.width.float * baseImg.height.float * 0.1).int)
    echo orders
    echo baseImg.toConsole()
    let stegano = quasiStegano2D(orders,baseImg,500)
    stegano.save("./piet.png",codelSize=10)