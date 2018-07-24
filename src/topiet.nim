import common
import pietbase
import pietize

proc toPiet(self:seq[seq[OrderAndArgs]]) :Matrix[PietColor]=
  let maxFunLen = self.mapIt(it.filterIt(not (it.order in[Goto,Goto])).len()).max()
  let width = maxFunLen + 8 + self.len() * 2
  let height = self.len() * 4 + 1
  var pietMap = newMatrix[PietColor](width,height)
  proc setMap(x,y:int,color:PietColor) =
    pietMap[self.len() * 2 + x + 4 ,2 + 4*y] = color
  # init
  for x in 0..<pietMap.width:
    for y in 0..<pietMap.height:
      pietMap[x,y] = WhiteNumber

  for y,orders in self:
    # 左のLabelジャンプ路
    block:
      # 最上部
      pietMap[2 * y + 2,0] = BlackNumber
      pietMap[2 * y + 2,1] = BlackNumber
      pietMap[2 * y + 1,0] = 0.PietColor
      # キャッチ
      pietMap[2*y+0,2+4*y] = 0.PietColor
      pietMap[2*y+1,2+4*y] = 0.PietColor
      pietMap[2*y+2,2+4*y] = 0.PietColor
      pietMap[2*y+0,1+4*y] = BlackNumber
      pietMap[2*y+2,1+4*y] = BlackNumber
      pietMap[2*y+0,3+4*y] = BlackNumber
      pietMap[2*y+2,3+4*y] = BlackNumber
      pietMap[0,1+4*y] = BlackNumber
      pietMap[0,2+4*y] = 0.PietColor
      pietMap[0,3+4*y] = BlackNumber

    # 分岐
    var jumpOrder = ErrorVPietType
    var jumpArgs = newSeq[int]()
    for x,order in orders:
      if order.order in [MoveTerminate,Goto,GoIf]:
        jumpOrder = order.order
        jumpArgs = order.args.mapIt(it.parseInt())
        break
    if jumpOrder == MoveTerminate:
      pietMap[width - 1,1 + y * 4] = BlackNumber
      pietMap[width - 1,2 + y * 4] = 0.PietColor
      pietMap[width - 1,3 + y * 4] = 0.PietColor
      pietMap[width - 2,3 + y * 4] = 0.PietColor
      pietMap[width - 3,3 + y * 4] = BlackNumber
      pietMap[width - 1,4 + y * 4] = BlackNumber
      pietMap[width - 2,4 + y * 4] = BlackNumber
      continue
    var nowColor = 0.PietColor
    pietMap[width - 2,2 + y * 4] = nowColor
    nowColor = nowColor.decideNext(Order.Push)
    pietMap[width - 1,2 + y * 4] = nowColor
    pietMap[width - 1,3 + y * 4] = nowColor
    nowColor = nowColor.decideNext(Order.Pointer)
    pietMap[width - 1,4 + y * 4] = nowColor
    case jumpOrder :
      of Goto:
        let x2 = 2 * jumpArgs[0] + 1
        let y2 = 4 + 4 * y
        pietMap[x2,y2] = 0.PietColor
        pietMap[x2-1,y2] = BlackNumber
      of GoIf:
        let y2 = 4 + 4 * y
        let minArg = min(jumpArgs[0],jumpArgs[1])
        let maxArg = max(jumpArgs[0],jumpArgs[1])
        nowColor = nowColor.decideNext(Order.Not)
        pietMap[width - 2,4 + y * 4] = nowColor
        nowColor = nowColor.decideNext(Order.Not)
        pietMap[width - 3,4 + y * 4] = nowColor
        pietMap[0+2*minArg,y2] = BlackNumber
        pietMap[1+2*minArg,y2] = 0.PietColor
        pietMap[2+2*maxArg,y2] = 0.PietColor
        pietMap[1+2*maxArg,y2] = 0.PietColor.decideNext(Order.Pointer)
        if jumpArgs[0] > jumpArgs[1]:
          pietMap[width - 2,4 + y * 4] = nowColor.decideNext(Order.Not)
      else: discard
  # 左端上
  pietMap[0,0] = 0.PietColor
  pietMap[0,1] = 0.PietColor
  pietMap[0,2] = 0.PietColor
  # write orders
  for y,orders in self:
    var nowColor = 0.PietColor
    pietMap[self.len() * 2 + 2 ,2 + 4*y] = nowColor
    pietMap[self.len() * 2 + 2 ,1 + 4*y] = nowColor
    pietMap[self.len() * 2 + 3 ,1 + 4*y] = BlackNumber
    setMap(0,y,nowColor)
    for x,order in orders:
      if order.order in [MoveTerminate,Goto,GoIf]: continue
      let pietOrder = order.operation
      nowColor = nowColor.decideNext(pietOrder)
      setMap(x+1,y,nowColor)
  return pietMap


if isMainModule:
  for filename in commandLineParams():
    filename.labeling().toPiet().save("nimcache/piet.png")