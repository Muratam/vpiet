import common
import pietbase
import pietize
import curse
import makegraph
# TODO 分岐なし/Gt=End版を完成させる
# 1D:
#   - ビームサーチで Wx1 の画像を作成 (最善であるDPとの比較も可能!!)
#     vpiet は 分岐なし -> とりあえず完全ランダムで
#     画像 は w x 1 -> とりあえず ある画像のラスタリングで
#     - [遊び] の部分を如何にして埋め込むかが重要(+Pop...)
#     - jpg系 と png系 で異なるかもしれない
#   - いい感じになってきたら vpietの方もランダム性減らしたい
# 2D:
#   - ビームサーチでWxH を作成
# type OrderAndArgs* = tuple[order:EMoveType,operation:Order,args:seq[string]]

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
proc distance(a,b:PietColor):int=
  let (ar,ag,ab) = a.toRGB()
  let (br,bg,bb) = b.toRGB()
  proc diff(x,y:uint8):int =
    let dist = abs(x.int-y.int)
    return dist
    # const th = min(0xc0-0x00,0xff-0xc0)
      # if dist < th : 0
      # elif dist < 0xff : 1
      # else : 2
  # 同じ:0 ~ 白->黒:6
  return diff(ar,br) + diff(ag,bg) + diff(ab,bb)

proc stegano1D*(orders:seq[OrderAndArgs],base:Matrix[PietColor]) : Matrix[PietColor] =
  # orders : inc dup ... push terminate
  doAssert orders[^1].operation == Terminate         ,"invalid"
  doAssert orders[0..^2].allIt(it.order == Operation),"invalid"
  doAssert base.height == 1
  doAssert base.width >= orders.len()
  result = newMatrix[PietColor](base.width,1)
  # https://photos.google.com/photo/AF1QipMlNFgMkP-_2AtsRZcYbPV3xkBjU0q8bKxql9p3?hl=ja
  # まずはDPで完全な解をさがす
  # dp [先端のcolor,進行したorder数,今までのNop数] (order+nopの順で進めていく)
  # dp [*,0,0] -> dp[*,1,0] (命令を進めた)
  #            -> dp[*,0,1] (Nopをした(C->White / White->C))
  #                        TODO : Nop (次がPushではないので同じ色)
  #                        TODO : 捨てる前提でPush/Not/Dup...を行う
  # echo orders
  # echo base.toConsole()
  let chromMax = hueMax * lightMax
  const EPS = 1e12.int
  # 有彩色 + 白 (黒は使用しない)
  # [color][Nop][Order]
  type DPTuple = tuple[val,pre,dNop,dOrd:int]
  const initDpTuple :DPTuple= (val:EPS,pre:WhiteNumber,dNop:0,dOrd:0)
  var dp = newSeqWith(chromMax + 1,newSeqWith(base.width,newSeqWith(base.width,initDpTuple)))
  block: # dp[*,0,0], 最初は白以外を置くはず
    let color = base[0,0]
    for i in 0..<chromMax:
      dp[i][0][0].val = distance(color,i.PietColor)
  for progress in 0..<(base.width-1):
    let baseColor = base[progress+1,0]
    for nop in 0..progress:
      let ord = progress - nop
      # もう命令を全て終えたやつ
      if ord >= orders.len(): continue
      # DP更新
      proc diff(color:int) : int = distance(baseColor,color.PietColor)
      proc update(dNop,dOrd,preColor,nextColor:int) =
        template preDp :untyped = dp[preColor][nop][ord]
        template nextDp:untyped = dp[nextColor][nop+dNop][ord+dOrd]
        let nextVal = preDp.val + diff(nextColor)
        if nextVal >= nextDp.val : return
        nextDp.val = nextVal
        nextDp.pre = preColor
        nextDp.dNop = dNop
        nextDp.dOrd = dOrd
      let order = orders[ord]
      # 命令を進めた
      for i in 0..<chromMax:
        let nextColor = i.PietColor.decideNext(order.operation).int
        update(0,1,i,nextColor)
      # Nopをした
      update(1,0,chromMax,chromMax) # 白 -> 白
      for i in 0..<chromMax: # ([]->白 | 白->[])
        update(1,0,i,chromMax)
        update(1,0,chromMax,i)
      # TODO: 同じ色Nop(chunk)
      # TODO: (Push)+(二項演算,Nop,Pop,Dup) 余剰数もDP

  proc showPath(startIndex,startNop,startOrd:int) =
    var index = startIndex
    var nop = startNop
    var ord = startOrd
    var indexes = newSeq[int]()
    while nop != 0 or ord != 0:
      indexes &= index
      let nowDp = dp[index][nop][ord]
      nop -= nowDp.dNop
      ord -= nowDp.dOrd
      index = nowDp.pre
    indexes &= index
    indexes.reverse()
    var echoMat = newMatrix[PietColor](indexes.len(),1)
    for i,index in indexes: echoMat[i,0] = index.PietColor
    echo dp[startIndex][startNop][startOrd].val,":",indexes.len()
    echo echoMat.toConsole()
    echo base.toConsole()
    echo echoMat.newGraph().mapIt(it.orderAndSizes.mapIt(it.order))
    echo orders
  var mins = newSeq[tuple[val,index,nop,ord:int]]()
  for progress in 0..<base.width:
    for nop in 0..progress:
      let ord = progress - nop
      if ord < orders.len(): continue
      let minIndex = toSeq(0..chromMax).mapIt(dp[it][nop][ord].val).argmin()
      let minVal = dp[minIndex][nop][ord].val
      if minVal == EPS : continue
      mins &= (minVal,minIndex,nop,ord)
  for m in mins.sorted((a,b)=>a.val - b.val)[0..min(3,mins.len())]:
    showPath(m.index,m.nop,m.ord)

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
  let baseImg = makeRandomPietColorMatrix(64,1)
  let stegano = stegano1D(orders,baseImg)
  # baseImg.save()
  # stegano.save()