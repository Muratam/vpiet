from PIL import Image
import sys
import os
import os.path
import scipy.misc
from colormath.color_objects import sRGBColor, LabColor
from colormath.color_conversions import convert_color
from colormath.color_diff import delta_e_cie2000

piet_colors = [
    "000", "222",
    "211", "221", "121", "122", "112", "212",
    "200", "220", "020", "022", "002", "202",
    "100", "110", "010", "011", "001", "101"
]
color_cache = {}


def to_piet_color(x, y, img):
    def get_mapped(mapped):
        color_map = [0, 192, 255]
        return color_map[int(mapped)]

    def calc_diff(r, g, b, rp, gp, bp):
        c1 = sRGBColor(r / 255.0, g / 255.0, b / 255.0)
        c2 = sRGBColor(get_mapped(rp) / 255.0,
                       get_mapped(gp) / 255.0,
                       get_mapped(bp) / 255.0)
        c1 = convert_color(c1, LabColor)
        c2 = convert_color(c2, LabColor)
        delta = delta_e_cie2000(c1, c2)
        return delta
    r, g, b, a = img.getpixel((x, y))
    if a == 0:
        decided_color = (255, 255, 255)
    else:
        r, g, b = r // 4 * 4, g // 4 * 4, b // 4 * 4
        pre_diff = 100000000
        decided_color = 0
        key = f"{r},{g},{b}"
        if key in color_cache:
            decided_color = color_cache[key]
        else:
            for (rp, gp, bp) in piet_colors:
                diff = calc_diff(r, g, b, rp, gp, bp)
                if diff < pre_diff:
                    decided_color = (get_mapped(
                        rp), get_mapped(gp), get_mapped(bp))
                    pre_diff = diff
            color_cache[key] = decided_color
    img.putpixel((x, y), decided_color)


def get_thumbnail(img):
    # to thumbnail
    basewidth = 200
    wpercent = (basewidth / float(img.size[0]))
    hsize = int((float(img.size[1]) * float(wpercent)))
    img = img.resize((basewidth, hsize), Image.ANTIALIAS)
    return img


def to_piet(imgname):
    # img = Image.open(imgname)
    img = scipy.misc.imread(imgname, mode='RGBA')
    img = Image.fromarray(img)
    for x in range(img.width):
        for y in range(img.height):
            to_piet_color(x, y, img)
    os.makedirs("output", exist_ok=True)
    outname = f"output/{os.path.basename(imgname)}"
    img.save(outname)
    print(outname)


def separate(imgname, sep_x, sep_y, begin_x, begin_y, end_x, end_y):
    # sep_{x,y} 個に分割してとる
    img = scipy.misc.imread(imgname, mode='RGBA')
    img = Image.fromarray(img)
    w = img.width / sep_x
    h = img.height / sep_y
    os.makedirs("separate", exist_ok=True)
    for x in range(sep_x):
        if x < begin_x or x >= end_x:
            continue
        for y in range(sep_y):
            if y < begin_y or y >= end_y:
                continue
            img.crop((w * x, h * y, w * (x + 1), h * (y + 1))
                     ).save(f"separate/x{x}y{y}i{os.path.basename(imgname)}")
    print(imgname)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("len(sys.argv) < 2")
        exit()
    for imgname in sys.argv[1:]:
        to_piet(imgname)
        # separate(imgname, 12, 8, 0, 0, 3, 4)
