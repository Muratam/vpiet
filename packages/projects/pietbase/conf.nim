# ここを変更すると調整できるように
type PietColorType* = enum
  # RGB<->PietColorの変換方式は自由
  NormalColor
type PietOrderType* = enum
  NormalOrder,TerminateAtGreater # 命令列の変換は自由

const pietColorType* = NormalColor
const pietOrderType* = NormalOrder
