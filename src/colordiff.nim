import common
import pietbase
import curse

proc toConsole*(pietMap:Matrix[PietColor]): string =
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
  result &= endAll & "\n"


# 色差関数
proc ciede2000*(l1,a1,b1,l2,a2,b2:float):float{. importc: "CIEDE2000" header: "../src/ciede2000.h".}

var ciede2000Table = newSeqWith(maxColorNumber+1, newSeqWith(maxColorNumber+1,-1))
proc distanceByCIEDE2000*(a,b:PietColor) : int =
  if ciede2000Table[a][b] >= 0 : return ciede2000Table[a][b]
  proc rgb2xyz(rgb:tuple[r,g,b:uint8]): tuple[x,y,z:float] =
    # http://w3.kcua.ac.jp/~fujiwara/infosci/colorspace/colorspace2.html
    proc lin(x:uint8) : float =
      let nx = x.float / 255
      if nx > 0.04045 : pow((nx+0.055)/1.055,2.4)
      else: nx / 12.92
    let (r,g,b) = rgb
    let (lr,lg,lb) = (r.lin, g.lin, b.lin)
    return (
      lr * 0.4124 + lg * 0.3576 + lb * 0.1805,
      lr * 0.2126 + lg * 0.7152 + lb * 0.0722,
      lr * 0.0193 + lg * 0.1192 + lb * 0.9505)
  proc xyz2lab(xyz:tuple[x,y,z:float]): tuple[l,a,b:float] =
    # http://w3.kcua.ac.jp/~fujiwara/infosci/colorspace/colorspace3.html
    proc lin(x:float) : float =
      if x > 0.008856 : pow(x, 1.0/3.0)
      else: 7.787 * x + 0.1379
    let (x,y,z) = xyz
    let (nx,ny,nz) = (lin(x / 0.95047), lin(y / 1.0 ), lin(z / 1.08883))
    return (116 * ny - 16,500 * (nx - ny),200 * (ny - nz))
  let (l1,a1,b1) = a.toRGB().rgb2xyz().xyz2lab()
  let (l2,a2,b2) = b.toRGB().rgb2xyz().xyz2lab()
  let distance = ciede2000(l1,a1,b1,l2,a2,b2).int * 5
  ciede2000Table[a][b] = distance
  return ciede2000Table[a][b]

proc distance*(a,b:PietColor) : int = distanceByCIEDE2000(a,b)

proc showDistance*() =
  var mat = newMatrix[PietColor](maxColorNumber + 1+2,maxColorNumber+1)
  for c in 0..maxColorNumber:
    mat[0,c] = c.PietColor
    mat[1,c] = -1.PietColor
    var colors = newSeq[tuple[val:int,color:PietColor]]()
    for x in 0..maxColorNumber:
      let dist = distance(x.PietColor,c.PietColor)
      colors &= (dist,x.PietColor)
    colors.sort((a,b)=>a.val-b.val)
    for i,vc in colors:
      mat[2+i,c] = vc.color
  echo mat.toConsole()
  quit()
