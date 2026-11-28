"""Recolore un socle empire (medium/large) d'après un socle small United.

Classes de pixels du socle empire source :
  strip  : bande latérale hors UV (63,96,124)
  arc    : vert (remplissage + traits d'arcs)
  accent : bleu (cadre, barre lumineuse) -- teinte différente selon la taille,
           donc correspondance par luminosité normalisée
  panel  : zones noires sans étoiles fermées par le cadre
  bg     : champ d'étoiles
Pour chaque faction, une table source -> cible est apprise par classe sur le
couple small/empire -> small/<faction>, puis appliquée au socle medium/large.
"""
from collections import deque
from PIL import Image


def load(p):
    im = Image.open(p).convert("RGB")
    return im.size, list(im.get_flattened_data())


def classify(size, px):
    w, h = size
    cls = [None] * len(px)
    for i, (r, g, b) in enumerate(px):
        if abs(r - 63) + abs(g - 96) + abs(b - 124) < 12:
            cls[i] = "strip"
        elif g > r + 15 and g > b + 15:
            cls[i] = "arc"
        elif b > r + 25 and b > g + 10:
            cls[i] = "accent"
    # composantes connexes des pixels restants : panneau (sans étoile) ou fond
    seen = bytearray(len(px))
    for start in range(len(px)):
        if cls[start] is not None or seen[start]:
            continue
        comp = []
        q = deque([start])
        seen[start] = 1
        while q:
            i = q.popleft()
            comp.append(i)
            x, y = i % w, i // w
            for j in ((i - 1) if x > 0 else -1, (i + 1) if x < w - 1 else -1,
                      (i - w) if y > 0 else -1, (i + w) if y < h - 1 else -1):
                if j >= 0 and not seen[j] and cls[j] is None:
                    seen[j] = 1
                    q.append(j)
        stars = sum(1 for i in comp if max(px[i]) > 90)
        kind = "bg" if stars > max(3, len(comp) * 0.002) else "panel"
        for i in comp:
            cls[i] = kind
    return cls


def bright(p):
    return max(p)


def accent_scale(px, cls):
    vals = sorted(bright(p) for p, c in zip(px, cls) if c == "accent")
    return vals[int(len(vals) * 0.9)] if vals else 255


class Model:
    def __init__(self, src, scls, dst):
        self.full = {}
        self.lum = {}
        self.ref = accent_scale(src, scls)
        acc = {}
        for s, c, d in zip(src, scls, dst):
            if c == "accent":
                k = bright(s) * 255 // self.ref
                _add(acc, (c, min(k, 255) >> 2), d)
                continue
            if c in ("arc", "strip"):
                _add(self.full, (c, s[0] >> 2, s[1] >> 2, s[2] >> 2), d)
            _add(self.lum, (c, bright(s) >> 2), d)
        self.acc = _mean(acc)
        # seules les couleurs fréquentes servent de correspondance exacte
        self.full = {k: (a[0] // a[3], a[1] // a[3], a[2] // a[3])
                     for k, a in self.full.items() if a[3] >= 2000}
        self.lum = _mean(self.lum)
        self.fill = self.full.get(("arc", 1, 13, 0)) or self.lum.get(("arc", 13))
        self.line = self.full.get(("arc", 31, 52, 25)) or self.fill

    def apply(self, px, cls):
        ref = accent_scale(px, cls)
        cache = {}
        out = []
        for p, c in zip(px, cls):
            key = (p, c)
            v = cache.get(key)
            if v is None:
                v = self._one(p, c, ref)
                cache[key] = v
            out.append(v)
        return out

    def _one(self, p, c, ref):
        if c == "accent":
            k = min(bright(p) * 255 // ref, 255) >> 2
            return _nearest(self.acc, c, k, 64) or p
        if c in ("arc", "strip"):
            v = self.full.get((c, p[0] >> 2, p[1] >> 2, p[2] >> 2))
            if v:
                return v
        if c == "arc":
            r, g, b = p
            if r > g - 25:  # étoile dans l'arc : remplissage éclairci
                k = min(max((r - 4) / 251, 0), 1) * 0.6
                return _lerp(self.fill, (255, 255, 255), k)
            t = min(max((g - 55) / 153, 0), 1)
            return _lerp(self.fill, self.line, t)
        return _nearest(self.lum, c, bright(p) >> 2, 64) or p


def _lerp(a, b, t):
    return tuple(int(round(x + (y - x) * t)) for x, y in zip(a, b))


def _add(t, k, d):
    a = t.get(k)
    if a is None:
        t[k] = [d[0], d[1], d[2], 1]
    else:
        a[0] += d[0]; a[1] += d[1]; a[2] += d[2]; a[3] += 1


def _mean(t):
    return {k: (a[0] // a[3], a[1] // a[3], a[2] // a[3]) for k, a in t.items()}


def _nearest(t, c, k, n):
    for dk in range(n):
        for kk in (k - dk, k + dk):
            v = t.get((c, kk))
            if v:
                return v
    return None


# ---------------------------------------------------------------------------
# Usage : python3 tools/gen_united_bases.py
# Régénère assets/ships-v2/bases/<taille>/<arc>/<faction>.png (small, medium,
# large ; tous les arcs) à partir de bases/small/frontback/<faction>.png :
# couleurs apprises sur le couple small/frontback/empire -> <faction>, puis
# appliquées zone par zone à <taille>/<arc>/empire.png. Pillow seul est requis.
SIZES = ("small", "medium", "large")

if __name__ == "__main__":
    import glob
    import os
    base = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ships-v2", "bases")
    classic = {"empire", "first-order", "rebel", "republic", "resistance", "scum", "separatists"}
    size, src = load(f"{base}/small/frontback/empire.png")
    scls = classify(size, src)
    targets = {}
    for s in SIZES:
        for empire in sorted(glob.glob(f"{base}/{s}/*/empire.png")):
            combo = os.path.relpath(os.path.dirname(empire), base)
            if combo == "small/frontback":
                continue
            tsize, tpx = load(empire)
            targets[combo] = (tsize, tpx, classify(tsize, tpx))
    print("cibles :", ", ".join(targets))
    for f in sorted(glob.glob(f"{base}/small/frontback/*.png")):
        name = os.path.basename(f)[:-4]
        if name in classic:
            continue
        model = Model(src, scls, load(f)[1])
        for combo, (tsize, tpx, tcls) in targets.items():
            im = Image.new("RGB", tsize)
            im.putdata(model.apply(tpx, tcls))
            im.save(f"{base}/{combo}/{name}.png", optimize=True)
        print(name)
