import nimPNG

import pietbase/dpcc, pietbase/order, pietbase/color, pietbase/orderconf, pietbase/colorconf
export dpcc, order, color, orderconf, colorconf

proc getPietColor*(img:PNGResult,start:int): PietColor =
  let
    r = cast[uint8](img.data[start])
    g = cast[uint8](img.data[start+1])
    b = cast[uint8](img.data[start+2])
  return toPietColor(r,g,b)
