from PIL import Image
import sys
import os
import os.path
import scipy.misc
from colormath.color_objects import sRGBColor, LabColor
from colormath.color_conversions import convert_color
from colormath.color_diff import delta_e_cie2000
from statistics import median


def decline(imgname):
    n = 10
    # img = Image.open(imgname)
    img = scipy.misc.imread(imgname, mode='RGBA')
    img = Image.fromarray(img)
    print(img.height)
    res = Image.new("RGBA", (int(img.width / n), int(img.height / n)))
    for x in range(res.width):
        for y in range(res.height):
            rs, gs, bs, aas = [], [], [], []
            for nx in range(n):
                for ny in range(n):
                    r, g, b, a = img.getpixel((x * n + nx, y * n + ny))
                    rs.append(r)
                    gs.append(g)
                    bs.append(b)
                    aas.append(a)
            res.putpixel((x, y), (int(median(rs)), int(
                median(gs)), int(median(bs)), int(median(aas))))
    os.makedirs("output", exist_ok=True)
    outname = f"output/{os.path.basename(imgname)}"
    res.save(outname)
    print(outname)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("len(sys.argv) < 2")
        exit()
    for imgname in sys.argv[1:]:
        decline(imgname)
