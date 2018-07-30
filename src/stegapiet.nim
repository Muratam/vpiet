import common
import pietbase
import pietize
import curse
import makegraph

# 状態数が多すぎて愚直なビームサーチでは程遠い
# DP[color][nop][ord][fund] で progress = nop+ord 毎に回す
# 探索的手法: 同じ [0..ord] 空間内に N個の [PietMat,先頭{Color,DP,CC,Fund}] を用意して
#         : 次の [0..ord+1] 空間に飛ばす(N^2中の上位N個)
# N = 100 でもそれなりによい結果
#
# 既に配置されたものは確定済み(それ以上(有彩色であれば)必ず広げない)と仮定
# => 隣接マスに同じ色があれば破綻というチェックができる
# 配置する時に
# 次位置(by x,y,dp,cc)を確定させて行けるか確認
# 交差しうる(交差するときは引き伸ばしはしない+ループに入らなければOKというルールにすればOK)
# 新しく配置したやつが既に配置したものと被ることもある
# 黒ポチターン
# Piet08ですか ?(とりあえず白の先を{黒,壁}にしなければOK)



if pietOrderType != TerminateAtGreater:
  quit("only TerminateAtGreater is allowed")

const chromMax = hueMax * lightMax

proc getEightDirection(self: Matrix[PietColor],x,y:int) : EightDirection[Pos] =
  # 現在位置から次の8方向を探索して返す
  let color = self[x,y]
  doAssert color >= 0 and color < chromMax
  var searched = newMatrix[bool](self.width,self.height)
  searched.point((x,y)=>false)
  var stack = newStack[Pos]()
  let here = (x.int32,y.int32)
  stack.push(here)
  var endPos : EightDirection[Pos]= (here,here,here,here,here,here,here,here)
  proc updateEndPos(x,y:int32) =
    if y < endPos.upR.y : endPos.upR = (x,y)
    elif y == endPos.upR.y and x > endPos.upR.x : endPos.upR = (x,y)
    if y < endPos.upL.y : endPos.upL = (x,y)
    elif y == endPos.upL.y and x < endPos.upL.x : endPos.upL = (x,y)
    if y > endPos.downR.y : endPos.downR = (x,y)
    elif y == endPos.downR.y and x < endPos.downR.x : endPos.downR = (x,y)
    if y > endPos.downL.y : endPos.downL = (x,y)
    elif y == endPos.downL.y and x > endPos.downL.x : endPos.downL = (x,y)
    if x < endPos.leftR.x : endPos.leftR = (x,y)
    elif x == endPos.leftR.x and y < endPos.leftR.y : endPos.leftR = (x,y)
    if x < endPos.leftL.x : endPos.leftL = (x,y)
    elif x == endPos.leftL.x and y > endPos.leftL.y : endPos.leftL = (x,y)
    if x > endPos.rightR.x : endPos.rightR = (x,y)
    elif x == endPos.rightR.x and y > endPos.rightR.y : endPos.rightR = (x,y)
    if x > endPos.rightL.x : endPos.rightL = (x,y)
    elif x == endPos.rightL.x and y < endPos.rightL.y : endPos.rightL = (x,y)
  template searchNext(x2,y2:int32,op:untyped): untyped =
    block:
      let x {.inject.} = x2
      let y {.inject.} = y2
      if op and not searched[x,y] and self[x,y] == color:
        searched[x,y] = true
        stack.push((x,y))
  while not stack.isEmpty():
    let (x,y) = stack.pop()
    updateEndPos(x,y)
    searchNext(x-1,y  ,x >= 0)
    searchNext(x+1,y  ,x < self.width)
    searchNext(x  ,y-1,y >= 0)
    searchNext(x  ,y+1,y < self.height)
  return endPos

proc getNextPos(endPos:EightDirection[Pos],dp:DP,cc:CC) : tuple[x,y:int] =
  let (x,y) = endPos[cc,dp]
  let (dX,dY) = dp.getdXdY()
  return (x + dX,y + dY)

proc toConsole(pietMap:Matrix[PietColor]): string =
  result = ""
  for y in 0..<pietMap.height:
    for x in 0..<pietMap.width:
      let color = pietMap[x,y]
      let (r,g,b) = color.toRGB()
      proc to6(i:uint8):int = (if i == 0xff: 5 elif i == 0xc0: 3 else:1 )
      let c = case color:
        of WhiteNumber :
          getColor6(5,5,5).toBackColor() & getColor6(3,3,3).toForeColor() & '-'
        of BlackNumber :
          getColor6(0,0,0).toBackColor() & getColor6(2,2,2).toForeColor() & '*'
        else:
          getColor6(r.to6,g.to6,b.to6).toBackColor() & ' '
      result &=  c
    if y != pietMap.height - 1 : result &= "\n"
  result &= endAll


proc `$`(orders:seq[OrderAndArgs]):string =
  result = ""
  for order in orders:
    case order.order :
    of Operation:
      if order.operation == Push : result &= "+" & order.args[0]
      else: result &= $order.operation
    else: result &= $order.order
    result &= " "

# 色差関数
proc distance(a,b:PietColor) : int =
  # if a == b : return 0
  # const w = 10
  # const maxW = ((w * hueMax div 2) + lightMax ) * 2
  # if a == WhiteNumber and b == BlackNumber : return maxW
  # if a == BlackNumber and b == WhiteNumber : return maxW
  # if a == WhiteNumber : return w+b.light
  # if b == WhiteNumber : return w+a.light
  # if a == BlackNumber : return w+2-b.light
  # if b == BlackNumber : return w+2-a.light
  # return abs(a.light - b.light) + w * min(abs(a.hue - b.hue),abs(abs(a.hue - b.hue) - hueMax))
  let (ar,ag,ab) = a.toRGB()
  let (br,bg,bb) = b.toRGB()
  proc diff(x,y:uint8):int =
    let dist = abs(x.int-y.int)
    return dist
    # const th = min(0xc0-0x00,0xff-0xc0)
    # return
    #   if dist < th : 0
    #   elif dist < 0xff : 1
    #   else : 2
  # 同じ:0 ~ 白->黒:6
  return diff(ar,br) + diff(ag,bg) + diff(ab,bb)

var colorTable = newSeqWith(PietColor.high.int+1,newSeqWith(Order.high.int+1,-1))
proc getNextColor(i:int,operation:Order):int = #i.PietColor.decideNext(operation)
  if colorTable[i][operation.int] == -1:
    colorTable[i][operation.int] = i.PietColor.decideNext(operation)
  return colorTable[i][operation.int]

proc checkStegano1D(orders:seq[OrderAndArgs],base:Matrix[PietColor]) =
  # orders : inc dup ... push terminate
  doAssert orders[^1].operation == Terminate         ,"invalid"
  doAssert orders[0..^2].allIt(it.order == Operation),"invalid"
  doAssert base.height == 1
  doAssert base.width >= orders.len()

proc stegano1D*(orders:seq[OrderAndArgs],base:Matrix[PietColor]) =
  checkStegano1D(orders,base)
  # result = newMatrix[PietColor](base.width,1)
  # https://photos.google.com/photo/AF1QipMlNFgMkP-_2AtsRZcYbPV3xkBjU0q8bKxql9p3?hl=ja
  const EPS = 1e12.int
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

proc quasiStegano2D*(orders:seq[OrderAndArgs],base:Matrix[PietColor]) =
  echo base.toConsole(),"\n"
  const maxFrontierNum = 400
  const maxEmbedColor = 20
  type Val = tuple[val:int,mat:Matrix[PietColor],x,y:int,dp:DP,cc:CC,fund:int]
  proc isIn(x,y:int):bool = x >= 0 and y >= 0 and x < base.width and y < base.height
  proc updateMat(f:var Val,x,y:int,color:PietColor) =
    if f.mat[x,y] == color: return
    f.mat[x,y] = color
    f.val += distance(color,base[x,y]) - 1
  proc isDecided(mat:Matrix[PietColor],x,y:int) : bool = mat[x,y] >= 0
  proc isChromatic(mat:Matrix[PietColor],x,y:int) : bool = mat[x,y] >= 0 and mat[x,y] < chromMax
  proc checkAdjast(mat:Matrix[PietColor],color:PietColor,x,y:int) : bool =
    for dxdy in [(0,1),(0,-1),(1,0),(-1,0)]:
      let (dx,dy) = dxdy
      let (nx,ny) = (x + dx,y + dy)
      if not isIn(nx,ny) : continue
      if mat[nx,ny] == color : return true
    return false
  proc checkNextIsNotDecided(mat:Matrix[PietColor],x,y:int,dp:DP,cc:CC) : bool =
    let (cX,cY) = mat.getEightDirection(x,y).getNextPos(dp,cc)
    if not isIn(cX,cY) or mat.isDecided(cX,cY) : return false
    return true

  type EmbedColorType = tuple[mat:Matrix[PietColor],val:int]
  proc embedColor(startMat:Matrix[PietColor],startVal,startX,startY:int,color:PietColor,onlyOne=false): seq[EmbedColorType] =
    # 未確定の場所を埋めれるだけ埋めてゆく(ただし上位スコアmaxEmbedColorまで)
    # ただし,埋めれば埋めるほど当然損なので,最大でもmaxEmbedColorマスサイズにしかならない
    doAssert color < chromMax
    var stack = newStack[tuple[x,y,val:int,mat:Matrix[PietColor]]]()
    # q.top()が一番雑魚になる
    var q = newBinaryHeap[EmbedColorType](proc(x,y:EmbedColorType): int = y.val - x.val)
    stack.push((startX,startY,startVal,startMat))
    while not stack.isEmpty():
      # WARN: 一筆書きできるようにしか配置できない！
      let (x,y,val,mat) = stack.pop()
      if not isIn(x,y) : continue
      if mat.isDecided(x,y) : continue
      if startMat.checkAdjast(color,x,y) : continue
      var newMat = mat.deepCopy()
      newMat[x,y] = color
      # 確定している量が多いほどちょっと偉い
      let newVal = val + distance(color,base[x,y]) - 1
      let next : EmbedColorType = (newMat,newVal)
      if q.len() > maxEmbedColor: # 多すぎるときは一番雑魚を省く
        if q.top().val <= next.val : continue
        discard q.pop()
      q.push(next)
      if onlyOne : break # 一つだけほしいときはすぐにリタイア
      stack.push((x+1,y,newVal,newMat))
      stack.push((x-1,y,newVal,newMat))
      stack.push((x,y+1,newVal,newMat))
      stack.push((x,y-1,newVal,newMat))
    result = @[]
    var pre : EmbedColorType
    var isFirst = true
    while q.len() > 0:
      if isFirst :
        pre = q.pop()
        result &= pre
        isFirst = false
        continue
      let next = q.pop()
      let isSame = (proc ():bool =
        for x in 0..<startMat.width:
          for y in 0..<startMat.height:
            if pre.mat[x,y] != next.mat[x,y] : return false
        return true
      )()
      if isSame : continue
      pre = next
      result &= pre
  proc tryAllDPCC(mat:Matrix[PietColor],eightDirection:EightDirection[Pos],startDP:DP,startCC:CC) : tuple[ok:bool,dp:DP,cc:CC]=
    # 次に壁ではない場所にいけるなら ok
    var dp = startDP
    var cc = startCC
    for i in 0..<8:
      let (nX,nY) = eightDirection.getNextPos(dp,cc)
      if not isIn(nX,nY) or mat[nX,nY] == BlackNumber:
        if i mod 2 == 0 : cc.toggle()
        else: dp.toggle(1)
        continue
      return (true,dp,cc)
    return (false,dp,cc)

  # index == ord | N個の [PietMat,先頭{Color,DP,CC,Fund}]
  var fronts = newSeqWith(1,newSeq[Val]())
  block: # 最初は白以外
    for i in 0..<chromMax:
      var initMat = newMatrix[PietColor](base.width,base.height)
      initMat.point((x,y) => -1)
      let choises = initMat.embedColor(0,0,0,i.PietColor)
      for choise in choises:
        fronts[0] &= (choise.val,choise.mat,0,0,newDP(),newCC(),0)
      fronts = fronts.mapIt(it.sorted((a,b)=>a.val-b.val)[0..min(it.len(),maxFrontierNum)-1])
  for progress in 0..<(base.width * base.height):
    var nexts = newSeqWith(min(fronts.len(),orders.len())+1,newSeq[Val]())
    for ord in 0..<fronts.len():
      let front = fronts[ord]
      if ord == orders.len():
        for f in front: nexts[ord] &= f
        continue
      let order = orders[ord]
      for f in front:
        let hereColor = f.mat[f.x,f.y]
        if hereColor >= chromMax : continue # 簡単のために白は経由しない
        let endPos = f.mat.getEightDirection(f.x,f.y)
        proc decide(dOrd:int,dFund:int,color:PietColor,onlyOne:bool) =
          let (ok,dp,cc) = f.mat.tryAllDPCC(endPos,f.dp,f.cc)
          if not ok : return
          let (nX,nY) = endPos.getNextPos(dp,cc)
          if f.mat.isDecided(nX,nY) : # このままいけそうなら交差してみます
            if f.mat[nX,nY] != color : return
            if not f.mat.checkNextIsNotDecided(nX,nY,dp,cc): return
            nexts[ord+dOrd] &= (f.val,f.mat.deepCopy(),nX,nY,dp,cc,f.fund + dFund)
            return
          # 次がPushなら Push 1 なので 1マスだけなのに注意
          let choises = f.mat.embedColor(f.val,nX,nY,color,onlyOne)
          for choise in choises:
            nexts[ord+dOrd] &= (choise.val,choise.mat,nX,nY,dp,cc,f.fund + dFund)
          return

        if f.fund == 0: # 命令を進められるのは fund == 0 のみ
          let nextIsPush = if ord + 1 < orders.len() : orders[ord+1].operation  == Push else: false
          let nextColor = hereColor.getNextColor(order.operation)
          decide(1,0,nextColor.PietColor,nextIsPush)
        (proc = # 次の行き先に1マスだけ黒ポチー
          let (bX,bY) = endPos.getNextPos(f.dp,f.cc)
          if not isIn(bX,bY): return
          # 既に黒が置かれているならわざわざ置く必要がない
          if f.mat.isDecided(bX,bY) : return
          var next : Val = (f.val,f.mat.deepCopy(),f.x,f.y,f.dp,f.cc,f.fund)
          next.updateMat(bX,bY,BlackNumber)
          nexts[ord] &= next
        )()
        (proc = # 白を使うNop (WARN: 簡単のためにPiet08/KMCPietどちらでも動くような置き方しかしていません)
          # x - - - y (-の数N * 次の色C)
          let (ok,dp,cc) = f.mat.tryAllDPCC(endPos,f.dp,f.cc)
          if not ok : return
          let (dx,dy) = dp.getdXdY()
          var (x,y) = endPos.getNextPos(dp,cc)
          for i in 1..max(base.width,base.height):
            let (cx,cy) = (x+dx*i,y+dy*i)
            # 流石にはみ出したら終了
            if not isIn(x,y) : break
            if not isIn(cx,cy) : break
            # 伸ばしている途中でいい感じになる可能性があるので continue
            # 全て道中は白色にできないといけない
            if (proc ():bool =
              for j in 0..<i:
                let (jx,jy) = (x+dx*j,y+dy*j)
                if f.mat[jx,jy] != WhiteNumber and f.mat.isDecided(jx,jy) : return true
              return false
              )() : continue
            proc toWhites(f:var Val) =
              for j in 0..<i:
                let (jx,jy) = (x+dx*j,y+dy*j)
                f.updateMat(jx,jy,WhiteNumber)

            if f.mat.isDecided(cx,cy):
              # 交差するが行けるときはいく
              if not f.mat.isChromatic(cx,cy) : continue
              if not f.mat.checkNextIsNotDecided(cx,cy,dp,cc) : continue
              var next : Val = (f.val,f.mat.deepCopy(),cx,cy,dp,cc,f.fund)
              next.toWhites()
              nexts[ord] &= next
              continue
            for c in 0..<chromMax:
              if f.mat.checkAdjast(c.PietColor,cx,cy) : continue
              var next : Val = (f.val,f.mat.deepCopy(),cx,cy,dp,cc,f.fund)
              next.toWhites()
              next.updateMat(cx,cy,c.PietColor)
              nexts[ord] &= next
        )()
        # fund
        decide(0,1,hereColor.getNextColor(Push).PietColor,false)
        if f.fund > 0 : # WARN: DP,CCとして捨てることも可能(一緒に回す?(解析が面倒(DP/CCの数字がなにかかなり不明)なので気をまだやっていない))
          decide(0,-1,hereColor.getNextColor(Pop).PietColor,false)
          decide(0,0,hereColor.getNextColor(Not).PietColor,false)
          decide(0,1,hereColor.getNextColor(Dup).PietColor,false)
        if f.fund > 1:
          decide(0,-1,hereColor.getNextColor(Add).PietColor,false)
          decide(0,-1,hereColor.getNextColor(Sub).PietColor,false)
          decide(0,-1,hereColor.getNextColor(Mul).PietColor,false)
          decide(0,-1,hereColor.getNextColor(Div).PietColor,false)
          decide(0,-1,hereColor.getNextColor(Mod).PietColor,false)
    fronts = nexts.mapIt(it.sorted((a,b)=>a.val-b.val)[0..min(it.len(),maxFrontierNum)-1])
    let front = fronts[^1]
    for i in 0..<front.len():
      echo "->{front[i].val}".fmt()
      echo front[i].mat.toConsole() & "\n"
      echo front[i].mat.newGraph().mapIt(it.orderAndSizes.mapIt(it.order))
      echo base.toConsole()
      echo orders
      if i >= 0: break

proc makeRandomOrders(length:int):seq[OrderAndArgs] =
  randomize()
  proc getValidOrders():seq[Order] =
    result = @[]
    for oo in orderBlock:
      for o in oo:
        if o notin [ErrorOrder,Terminate,Pointer,Switch] :
          result &= o
  result = newSeq[OrderAndArgs]()
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
  if false:
    let orders = makeRandomOrders(20)
    let baseImg = makeRandomPietColorMatrix(64,1)
    stegano1D(orders,baseImg)
    quasiStegano1D(orders,baseImg)
  if true:
    let orders = makeRandomOrders(30)
    let baseImg = makeLocalRandomPietColorMatrix(10,10)
    quasiStegano2D(orders,baseImg)
  # baseImg.save()
  # stegano.save()