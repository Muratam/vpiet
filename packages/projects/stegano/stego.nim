{.experimental: "notnil".}
import packages/[common, pietbase, frompiet, curse]
import pasm, steganoutil
import blockinfo, node, target
import sets, hashes, tables
# import nimprof
# TODO: if / while の実装
#      (一括変更の実装)
#      for deep learning の実装:
#      既存研究からの架け橋つなぎ


# まずは一本自由にTerminateまで作成.(x1000くらい解が得られるだろう)
# その後 A-> A' のようにブランチを生やさせる(生える場所はDP/CCどちらでも).
# if (elseなし) と do while だけを使用するときれいになる
# 最初に本筋を作った後,「繋げるためだけ」の空の命令列のブランチを生やせば良くなるのでだいぶ問題が制約されて楽
# if else と while からそれに変換もまあ頑張ればできるはず


proc quasiStegano2D*(env: NodeEnv): Matrix[PietColor] =
  # 最悪全部塗り終わるまで繰り返す
  for progress in 0..<(env.width * env.height):
    env.prepare()
    for ord in 0..env.orders.len():
      env.processFront(ord)
    env.setupNextFronts()
    if not env.checkIterateResult(): break
  return env.getResult()



proc getPietOrder(): seq[EmbOrder] =
  proc d(ord: Order, n: int = -1): EmbOrder =
    if ord == Push: return newPushEmbOrder(n)
    return ord.newEmbOrder()
  result = @[]
  let orderP = @[d(Push, 3), d(Dup), d(Mul), d(Dup), d(Mul), d(Push, 1),
    d(Sub), d(Dup), d(OutC)]
  let orderI = @[d(Push, 3), d(Dup), d(Push, 1), d(Add), d(Add), d(Sub),
    d(Dup), d(OutC)]
  let orderE = @[d(Push, 2), d(Dup), d(Add), d(Sub), d(Dup), d(OutC)]
  let orderT = @[d(Push, 3), d(Dup), d(Push, 2), d(Add), d(Mul), d(Add),
    d(OutC)]
  let orders = orderP & orderI & orderE & orderT
  for i in 0..<1: result &= orders
  result &= Terminate.newEmbOrder()


proc getBranchedOrders(): seq[EmbOrder] =
  result = @[]
  var connectFaze = newSeq[EmbOrder]()
  var index = -1
  proc d(ord: Order, n: int = -1): EmbOrder =
    index += 1
    if ord == Push: return newPushEmbOrder(n)
    if ord in [Switch, Pointer]:
      connectFaze &= newConnectEmbOrder(index, n)
    return ord.newEmbOrder()
  # ---2 1 1 1 1 1 2 と出力-----------------
  # A[push 2 && outn && push 5]
  # do : B[push 1 && outn && push 1 && sub && dup not not]: while!(pop == 0)
  # C[push 2 && outn && terminate]
  # --------------------
  # A[] - B[] - Switch{1:B} - C[]
  # Pointer or Switch で表現.
  #
  var orders = @[
    d(Push, 2), d(OutN), d(Push, 5), # A
    d(Push, 1), d(OutN), d(Push, 1), d(Sub), d(Dup), d(Not), d(Not),
      d(Pointer, 3), # B ((絶対アドレス 0-indexed) 1 のときは 3番目マスへジャンプしたい)
    d(Push, 2), d(OutN), # C
  ]
  result &= orders
  result &= Terminate.newEmbOrder()
  result &= connectFaze


if isMainModule:
  calcTime:
    printMemories()
    if commandLineParams().len() == 0:
      discard
      # let orders = makeRandomOrders(20)
      # let baseImg = makeLocalRandomPietColorMatrix(12, 12)
      # discard newEnv(
      #   baseImg, orders,
      #   maxFrontierNum = 720,
      #   maxFundLevel = 6,
      #   maxTrackBackOrderLen = 30)
      # .quasiStegano2D()
    else:
      let baseImg = commandLineParams()[0].newPietMap().pietColorMap
      const orders = getBranchedOrders() #getPietOrder()
      let stegano = newEnv(
        baseImg, orders,
        maxFrontierNum = 720,
        maxFundLevel = 6,
        maxTrackBackOrderLen = 30)
      .quasiStegano2D()
      stegano.save("./piet.png", codelSize = 10)
