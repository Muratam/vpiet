import nimPNG
import color

type PietColorType* = enum
  NormalColor # RGB<->PietColorの変換方式は自由

const pietColorType = NormalColor

when pietColorType == NormalColor:
  proc toRGB*(c:PietColor):tuple[r,g,b:uint8] =
    const x00 = 0.uint8
    const xc0 = 192.uint8
    const xff = 255.uint8
    case c:
    of WhiteNumber: return (xff,xff,xff)
    of BlackNumber: return (x00,x00,x00)
    else:
      let l = if c.light == 0 : xc0 else: x00
      let h = if c.light == 2 : xc0 else: xff
      return case c.hue:
        of 0: (h,l,l)
        of 1: (h,h,l)
        of 2: (l,h,l)
        of 3: (l,h,h)
        of 4: (l,l,h)
        of 5: (h,l,h)
        else: (h,h,h)
  proc toPietColor*(r,g,b:uint8) : PietColor =
    if r == g and g == b :
      if r == 255u8: return WhiteNumber
      return BlackNumber
    let hue :PietColor =
      if r > g and g == b : 0
      elif r == g and g > b : 1
      elif r < g and g > b : 2
      elif r < g and g == b : 3
      elif r == g and g < b : 4
      else : 5
    # isDark
    if r <= 192u8 and g <= 192u8 and b <= 192u8: return hue + 12
    # isLight
    if r >= 192u8 and g >= 192u8 and b >= 192u8: return hue
    # normal
    return 6 + hue


proc getPietColor*(img:PNGResult,start:int): PietColor =
  let
    r = cast[uint8](img.data[start])
    g = cast[uint8](img.data[start+1])
    b = cast[uint8](img.data[start+2])
  return toPietColor(r,g,b)
