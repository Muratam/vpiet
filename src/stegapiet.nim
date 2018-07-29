import common
import pietbase
import pietize
import curse
import makegraph
import heapqueue

# 分岐なし/Gt=End版を完成させる
# 状態数が多すぎて愚直なビームサーチでは程遠い
# DP[color][nop][ord][fund] で progress = nop+ord 毎に回す
# 探索的手法: 同じ [0..ord] 空間内に N個の [PietMat,先頭{Color,DP,CC,Fund}] を用意して
#         : 次の [0..ord+1] 空間に飛ばす(N^2中の上位N個)


if pietOrderType != TerminateAtGreater:
  quit("only TerminateAtGreater is allowed")

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
  let chromMax = hueMax * lightMax
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
  # TODO: 同じ色Nop(chunk)
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
  for m in mins.sorted((a,b)=>dp[a].val - dp[b].val)[0..<min(3,mins.len())]:
    showPath(m)

proc quasiStegano1D*(orders:seq[OrderAndArgs],base:Matrix[PietColor]) =
  # ビームサーチでそれなりによいものを探す
  checkStegano1D(orders,base)
  #[
  type Key = tuple[color,nop,ord,fund:int]
  type Val = tuple[val:int,preKey:Key]
  let chromMax = hueMax * lightMax
  const maxFund = 10
  const EPS = 1e12.int
  const initVal :Val = (EPS,(0,0,0,0))
  var searched = newSeqWith(chromMax + 1,newSeqWith(base.width,newSeqWith(base.width,newSeqWith(maxFund,initVal))))
  var q = newHeapQueue[Val]() # tuple なので 前から順に小さい順に
  # q.push((0,(0,0,0,0)))
  block: # 最初は白以外
    let color = base[0,0]
    for i in 0..<chromMax:
      q.push((distance(color,i.PietColor),(i,0,0,0)))
  var loopIndex = 0
  while true:
    loopIndex += 1
    let (val,here) = q.pop() # here:color,nop,ord,fund
    if here.fund >= maxFund : continue
    # WARN: 始めて到達したものになる
    if searched[here.color][here.nop][here.ord][here.fund].val <= val: continue
    searched[here.color][here.nop][here.ord][here.fund] = (val,here)
    if here.ord >= orders.len() :
      quit("OK" & $here & $val)
    let progress = here.nop + here.ord
    let order = orders[here.ord]
    let baseColor = base[progress+1,0]
    proc diff(color:int) : int = distance(baseColor,color.PietColor)
    var pushList = newSeq[Val]()
    proc push(nextColor,dNop,dOrd,dFund:int,lazy=true) =
      let pushed = (val + diff(nextColor),(nextColor,here.nop + dNop,here.ord+dOrd,here.fund+dFund))
      if lazy : pushList &= pushed
      else : q.push(pushed)
    # 命令を進めた
    if here.fund == 0 :
      push(here.color.getNextColor(order.operation),0,1,0,lazy=false)
    # Nop
    # (* -> 白)
    push(chromMax,1,0,0)
    if here.color == chromMax: # (白 -> *)
      for i in 0..<chromMax: push(i,1,0,0)
    # Fund
    push(here.color.getNextColor(Push),1,0,1)
    # if ord+1 < orders.len() and orders[ord+1].operation != Push:
    #   update(d(i,0,0,0),d(i,1,0,0)) # 次Pushがわかってるのに増やすことはできない
    if here.fund > 0:
      push(here.color,1,0,0)
      push(here.color.getNextColor(Pop),1,0,-1)
      push(here.color.getNextColor(Not),1,0,0)
      push(here.color.getNextColor(Dup),1,0,1)
    if here.fund > 1:
      push(here.color.getNextColor(Add),1,0,-1)
      push(here.color.getNextColor(Sub),1,0,-1)
      push(here.color.getNextColor(Mul),1,0,-1)
      push(here.color.getNextColor(Div),1,0,-1)
      push(here.color.getNextColor(Mod),1,0,-1)
    # orderを進めるもの以外は上位3つでよいかな
    for pushed in pushList.sorted((a,b)=> a.val - b.val): # [0..<min(10,pushList.len())]:
      q.push(pushed)
    ]#



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

if isMainModule:
  let orders = makeRandomOrders(20)
  let baseImg = makeRandomPietColorMatrix(50,1)
  stegano1D(orders,baseImg)
  quasiStegano1D(orders,baseImg)
  # baseImg.save()
  # stegano.save()