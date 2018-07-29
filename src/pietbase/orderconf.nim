import order
type PietOrderType* = enum
  NormalOrder,TerminateAtGreater # 命令列の変換は自由
const pietOrderType* = TerminateAtGreater

when pietOrderType == NormalOrder:
  const orderBlock* = [
    [ErrorOrder,Push,Pop],
    [Add,Sub,Mul],
    [Div,Mod,Not],
    [Greater,Pointer,Switch],
    [Dup,Roll,InN],
    [InC,OutN,OutC],
  ]
elif pietOrderType == TerminateAtGreater:
  const orderBlock* = [
    [ErrorOrder,Push,Pop],
    [Add,Sub,Mul],
    [Div,Mod,Not],
    [Terminate,Pointer,Switch],
    [Dup,Roll,InN],
    [InC,OutN,OutC],
  ]
  # const orderBlock* = [
  #   [ErrorOrder,Push,Pop],
  #   [OutC,Sub,Terminate],
  #   [Div,Roll,Not],
  #   [Mul,Pointer,Switch],
  #   [Dup,Mod,InN],
  #   [InC,OutN,Add],
  # ]
