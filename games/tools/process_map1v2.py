#!/usr/bin/env python3
"""Phase 0 — prepare map1v2 art for the placer + grove.

Chroma-keys the matte backgrounds (magenta/blue/black/white) to transparency and slices the
composites/sheets into individual sprites:

  base_items.png  (magenta) -> items/<name>.png  + items_layout.json (auto-derived pos+fsize)
  base_trees.png  (magenta) -> trees/tree1..N.png
  base_grass.png  (blue)    -> grass/grass1..9.png   (3x3 grid)
  base_chimney.png(black)   -> chimney/frame0..8.png (3x3 grid, registered for a flipbook)
  base_clouds.png (blue)    -> clouds.png
  base_fence.png  (white)   -> fence.png             (edge flood-fill; keeps interior highlights)
  base_empty.jpg            -> used directly as the background (no processing)

Run:  /tmp/mapenv/bin/python games/tools/process_map1v2.py
"""
import json, os
import numpy as np
from PIL import Image
from scipy import ndimage

SRC = "assets/map1v2"
DESIGN_W, DESIGN_H = 1080.0, 1920.0   # the layout JSON expresses fsize in design-canvas px

# expected item centers (fraction of frame) -> name, from base_full's layout
ITEM_NAMES = {
    "cottage":  (0.47, 0.41),
    "garden":   (0.66, 0.68),
    "well":     (0.22, 0.78),
    "shed":     (0.85, 0.53),
    "doghouse": (0.67, 0.85),
    "flowerbox":(0.15, 0.61),
    "lantern":  (0.86, 0.82),
}

def hsv(a):
    r,g,b = a[...,0]/255., a[...,1]/255., a[...,2]/255.
    mx=np.maximum(np.maximum(r,g),b); mn=np.minimum(np.minimum(r,g),b)
    d=mx-mn; v=mx; s=np.where(mx==0,0,d/np.maximum(mx,1e-6))
    rc=(mx-r)/np.maximum(d,1e-6); gc=(mx-g)/np.maximum(d,1e-6); bc=(mx-b)/np.maximum(d,1e-6)
    h=np.where(mx==r,bc-gc,np.where(mx==g,2+rc-bc,4+gc-rc)); h=(h/6.0)%1.0
    h=np.where(d>1e-6,h,0)
    return h*360, s, v

def bg_mask(a, kind):
    h,s,v = hsv(a[...,:3].astype(float))
    if kind=="magenta":
        return (h>278)&(h<342)&(s>0.30)&(v>0.28)
    if kind=="blue":
        return (h>200)&(h<252)&(s>0.40)&(v>0.38)
    if kind=="black":
        return v<0.14
    if kind=="white":
        m=(v>0.90)&(s<0.13)
        # only white CONNECTED TO THE BORDER is background — interior highlights survive
        lab,_=ndimage.label(m)
        border=set(np.unique(np.concatenate([lab[0],lab[-1],lab[:,0],lab[:,-1]])))
        border.discard(0)
        return np.isin(lab,list(border))
    raise ValueError(kind)

def keyed_rgba(a, kind):
    bg = bg_mask(a, kind)
    fg = ~bg
    # 1px erosion of fg removes the thin chroma halo around edges
    fg = ndimage.binary_erosion(fg, iterations=1)
    out = np.dstack([a[...,:3], (fg*255).astype(np.uint8)])
    return out, fg

def load_rgb(name):
    return np.asarray(Image.open(os.path.join(SRC,name)).convert("RGB"))

def save(arr, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(arr, "RGBA").save(path)

def crop_to_alpha(rgba):
    ys,xs = np.where(rgba[...,3]>8)
    return rgba[ys.min():ys.max()+1, xs.min():xs.max()+1], (xs.min(),ys.min(),xs.max(),ys.max())

def erase_chimney_smoke(rgba):
    """Drop the baked PINK smoke wisp above the cottage chimney (the game animates smoke separately).
    Keyed on pink (hue~red, mid sat, high val), restricted to the upper-right region so the orange roof,
    tan chimney, and pink flowers at the base are untouched."""
    H,W = rgba.shape[:2]
    h,s,v = hsv(rgba[...,:3].astype(float))
    region = np.zeros((H,W),bool)
    region[0:int(0.27*H), int(0.55*W):int(0.92*W)] = True
    pink = ((h<22)|(h>344)) & (s>0.10) & (s<0.45) & (v>0.78)
    m = region & pink & (rgba[...,3]>8)
    m = ndimage.binary_dilation(m, iterations=3)   # also clear the soft anti-aliased halo
    rgba[m,3] = 0
    return rgba

# --- items: label blobs, name by nearest expected center, derive pos+fsize ---
def do_items():
    a = load_rgb("base_items.png"); H,W = a.shape[:2]
    rgba,fg = keyed_rgba(a,"magenta")
    lab,n = ndimage.label(fg)
    sizes = ndimage.sum(np.ones_like(lab),lab,range(1,n+1))
    layout = {"items":[]}
    used = set()
    for i in sorted(range(n), key=lambda k:-sizes[k]):
        if sizes[i] < 8000: continue
        idx=i+1
        ys,xs = np.where(lab==idx)
        ocx,ocy = (xs.min()+xs.max())/2/W, (ys.min()+ys.max())/2/H   # blob center, for naming
        name = min((nm for nm in ITEM_NAMES if nm not in used),
                   key=lambda nm: (ITEM_NAMES[nm][0]-ocx)**2+(ITEM_NAMES[nm][1]-ocy)**2)
        used.add(name)
        sub = np.zeros((H,W,4),np.uint8); sub[lab==idx]=rgba[lab==idx]
        crop,(x0,y0,x1,y1) = crop_to_alpha(sub)
        if name=="cottage":
            crop = erase_chimney_smoke(crop)
            ys2,xs2 = np.where(crop[...,3]>8)           # re-tighten; map the new bbox back to frame coords
            x0,y0,x1,y1 = x0+xs2.min(), y0+ys2.min(), x0+xs2.max(), y0+ys2.max()
            crop = crop[ys2.min():ys2.max()+1, xs2.min():xs2.max()+1]
        save(crop, f"{SRC}/items/{name}.png")
        cx,cy = (x0+x1)/2/W, (y0+y1)/2/H               # final center (smoke-free) for the layout
        wpx=(x1-x0)/W*DESIGN_W; hpx=(y1-y0)/H*DESIGN_H
        layout["items"].append({"item":name,"pos":[round(cx,4),round(cy,4)],"fsize":int(round(max(wpx,hpx)))})
        print(f"  item {name:9} center=({cx:.3f},{cy:.3f}) fsize={int(round(max(wpx,hpx)))}")
    json.dump(layout, open(f"{SRC}/items_layout.json","w"), indent="\t")
    print(f"  -> items_layout.json ({len(layout['items'])} items)")

def do_trees():
    a = load_rgb("base_trees.png"); H,W=a.shape[:2]
    rgba,fg = keyed_rgba(a,"magenta")
    lab,n = ndimage.label(fg)
    sizes = ndimage.sum(np.ones_like(lab),lab,range(1,n+1))
    k=0
    # top-to-bottom, left-to-right ordering
    blobs=[]
    for i in range(n):
        if sizes[i]<8000: continue
        ys,xs=np.where(lab==i+1); blobs.append((ys.min(),xs.min(),i+1))
    for _,_,idx in sorted(blobs):
        k+=1
        sub=np.zeros((H,W,4),np.uint8); sub[lab==idx]=rgba[lab==idx]
        crop,_=crop_to_alpha(sub)
        save(crop,f"{SRC}/trees/tree{k}.png")
    print(f"  -> trees/tree1..{k}.png")

def do_grid(name, kind, outdir, prefix, rows=3, cols=3, crop=True, registered=False):
    a = load_rgb(name); H,W=a.shape[:2]; ch,cw=H//rows,W//cols
    k=0
    for r in range(rows):
        for c in range(cols):
            k+=1
            cell=a[r*ch:(r+1)*ch, c*cw:(c+1)*cw]
            rgba,_=keyed_rgba(cell,kind)
            if registered:
                out=rgba
            elif crop and (rgba[...,3]>8).any():
                out,_=crop_to_alpha(rgba)
            else:
                out=rgba
            save(out,f"{SRC}/{outdir}/{prefix}{k}.png")
    print(f"  -> {outdir}/{prefix}1..{k}.png")

def do_simple(name, kind, out):
    a=load_rgb(name); rgba,_=keyed_rgba(a,kind); save(rgba,f"{SRC}/{out}")
    print(f"  -> {out}")

print("items:");   do_items()
print("trees:");   do_trees()
print("grass:");   do_grid("base_grass.png","blue","grass","grass")
print("chimney:"); do_grid("base_chimney.png","black","chimney","frame",registered=True)  # 9 registered frames
print("clouds:");  do_simple("base_clouds.png","blue","clouds.png")
print("fence:");   do_simple("base_fence.png","white","fence.png")
print("done.")
