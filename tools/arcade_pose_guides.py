"""Exact joint diagrams for image-generation references, never shipped as artwork.

The stance foot traverses opposite root travel. A 150px guide stride becomes
167 logical px when the 270px guide body is registered at 300px in game.
"""
from pathlib import Path
import math
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/source/arcade-v8/guides'
OUT.mkdir(parents=True, exist_ok=True)


def foot(phase):
    q = phase % 1.0
    if q < .6:
        return 45 - q / .6 * 90, -4
    t = (q - .6) / .4
    ease = t * t * (3 - 2 * t)
    return -45 + 90 * ease, -4 - math.sin(t * math.pi) * 24


def joint(a, b, upper, lower, bend=1):
    dx, dy = b[0] - a[0], b[1] - a[1]
    distance = max(.01, min(math.hypot(dx, dy), upper + lower - .01))
    total = max(.01, math.hypot(dx, dy))
    ux, uy = dx / total, dy / total
    along = (upper * upper - lower * lower + distance * distance) / (2 * distance)
    h = math.sqrt(max(0, upper * upper - along * along)) * bend
    return a[0] + ux * along - uy * h, a[1] + uy * along + ux * h


def draw_figure(draw, origin, p):
    def point(v):
        return origin[0] + v[0], origin[1] + v[1]
    def line(a, b, color, width):
        draw.line([point(a), point(b)], fill=color, width=width)
    for side, shade in [('far', '#829aaa'), ('near', '#24475d')]:
        hip = (p['hip'][0] + (-5 if side == 'far' else 5), p['hip'][1])
        ankle = p[side + '_foot']
        knee = joint(hip, ankle, 78, 78, -1)
        line(hip, knee, shade, 15)
        line(knee, ankle, shade, 12)
        line((ankle[0] - 7, ankle[1]), (ankle[0] + 17, ankle[1]), shade, 8)
        shoulder = (p['shoulder'][0] + (-6 if side == 'near' else 6), p['shoulder'][1])
        hand = p[side + '_hand']
        elbow = joint(shoulder, hand, 39, 39, 1)
        line(shoulder, elbow, shade, 13)
        line(elbow, hand, shade, 10)
    line(p['hip'], p['shoulder'], '#4c7185', 33)
    x, y = point(p['head'])
    draw.ellipse((x-15, y-19, x+15, y+19), fill='#ddbc95', outline='#24475d', width=2)
    # Small direction mark, not facial identity. Actual face comes from portrait.
    draw.polygon([(x+13,y-8),(x+22,y-2),(x+13,y+1)], fill='#ddbc95')
    for key in ['hip', 'shoulder', 'near_hand', 'far_hand', 'near_foot', 'far_foot']:
        x, y = point(p[key]); draw.ellipse((x-3,y-3,x+3,y+3),fill='#df4d51')


image = Image.new('RGB', (1280, 640), '#f1f4f5')
draw = ImageDraw.Draw(image)
for i in range(8):
    x, y = i % 4 * 320, i // 4 * 320
    phase = i / 8
    theta = phase * math.tau
    bob = math.sin(theta * 2) * 2.4
    p = {
        'hip': (math.sin(theta) * 2, -145 + bob),
        'shoulder': (4 + math.sin(theta + math.pi) * 3, -223 + bob),
        'head': (9 + math.sin(theta + math.pi) * 2, -251 + bob),
        'near_hand': (28 + math.sin(theta) * 4, -213 + bob),
        'far_hand': (60 + math.sin(theta + math.pi) * 4, -216 + bob),
        'near_foot': foot(phase),
        'far_foot': foot(phase + .5),
    }
    draw.line((x+5,y+300,x+315,y+300),fill='#ccd5dc',width=1)
    draw.line((x+140,y+295,x+140,y+305),fill='#df4d51',width=1)
    draw_figure(draw, (x + 140, y + 300), p)
image.save(OUT / 'walk-8.png')
print(OUT / 'walk-8.png')
