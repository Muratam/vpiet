import common
import pietbase
import pietize
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

proc steagno1D*(orders:seq[OrderAndArgs],base:Matrix[PietColor]) : Matrix[PietColor] =
  # orders : inc dup ... push terminate
  doAssert orders[^1].operation == Terminate         ,"invalid"
  doAssert orders[0..^2].allIt(it.order == Operation),"invalid"
  doAssert base.height == 1

  let maxFunLen = orders.filterIt(not (it.order in[Goto,Goto])).len()
  let width = maxFunLen + 8 + orders.len() * 2
  let height = orders.len() * 4 + 1
  var pietMap = newMatrix[PietColor](width,height)
  return pietMap

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
  let orders = makeRandomOrders(32)
  echo orders
  let baseImg = makeRandomPietColorMatrix(64,1)
  let stegano = steagno1D(orders,baseImg)
  # baseImg.save()
  # stegano.save()