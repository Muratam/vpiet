{.experimental: "notnil".}
import packages/[common, pietbase, frompiet, curse]
import pasm, steganoutil, blockinfo, node, target
import sets, hashes, tables

# TODO: if / while の実装
#       一括変更の実装
#      for deep learning の実装

proc quasiStegano2D*(env: NodeEnv): Matrix[PietColor] =
  # 最悪全部塗り終わるまで繰り返す
  for progress in 0..<(env.width * env.height):
    env.prepare()
    for ord in 0..env.orders.len():
      env.processFront(ord)
    env.setupNextFronts()
    if not env.checkIterateResult(): break
  return env.getResult()

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


if isMainModule:
  calcTime:
    printMemories()
    if commandLineParams().len() == 0:
      let orders = makeRandomOrders(20)
      let baseImg = makeLocalRandomPietColorMatrix(12, 12)
      discard newEnv(
        baseImg, orders,
        maxFrontierNum = 720,
        maxFundLevel = 6,
        maxTrackBackOrderLen = 30)
      .quasiStegano2D()
    else:
      let baseImg = commandLineParams()[0].newPietMap().pietColorMap
      const orders = getOrders()
      let stegano = newEnv(
        baseImg, orders,
        maxFrontierNum = 720,
        maxFundLevel = 6,
        maxTrackBackOrderLen = 30)
      .quasiStegano2D()
      stegano.save("./piet.png", codelSize = 10)
