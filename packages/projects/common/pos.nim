import stdimport
type Pos* = tuple[x,y:int32]
proc `+`*(a,b:Pos) : Pos = (a.x + b.x, a.y + b.y)
const PosUp* = (0.int32,-1.int32)
const PosDown* = (0.int32,1.int32)
const PosRight* = (1.int32,0.int32)
const PosLeft* = (-1.int32,0.int32)