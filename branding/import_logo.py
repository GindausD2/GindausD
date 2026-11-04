"""Trace the original monochrome logo into archival branding assets.

No generative redraw: contours follow the reference. Requires numpy, matplotlib,
Pillow, reportlab and PyMuPDF. The original JPEG remains unchanged.
The approved glacier-blue release artwork and native assets are not overwritten.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor
import fitz

ROOT=Path(__file__).resolve().parents[1]
BRAND=ROOT/'branding'
source=BRAND/'Max_Logo_Reference.jpeg'
image=np.asarray(Image.open(source).convert('L'))
fig,ax=plt.subplots()
cs=ax.contour(image, levels=[128])
polys=[]
for path in cs.get_paths():
 for polygon in path.to_polygons():
  area=abs(np.sum(polygon[:-1,0]*polygon[1:,1]-polygon[1:,0]*polygon[:-1,1]))/2
  if area>400: polys.append(polygon)
plt.close(fig)
assert len(polys)==3, f'Expected outer mark, ring opening, detached right curve; got {len(polys)}'

# Simplify subpixel contour steps, without changing the intentional cut.
def simplify(points, tolerance=0.55):
 if len(points)<3: return points
 start,end=points[0],points[-1]
 delta=end-start
 denom=np.linalg.norm(delta)
 if denom<1e-9: distances=np.linalg.norm(points-start,axis=1)
 else: distances=np.abs(delta[0]*(start[1]-points[:,1])-(start[0]-points[:,0])*delta[1])/denom
 index=int(np.argmax(distances))
 if distances[index]>tolerance:
  return np.concatenate([simplify(points[:index+1],tolerance)[:-1],simplify(points[index:],tolerance)])
 return points[[0,-1]]

allpts=np.concatenate(polys)
x0,y0=allpts.min(axis=0);x1,y1=allpts.max(axis=0)
w,h=x1-x0,y1-y0
normalized=[]
for poly in polys:
 poly=simplify(poly)
 normalized.append([(round(float((x-x0)/w*1000),3),round(float((y-y0)/w*1000),3)) for x,y in poly])
height=h/w*1000

def svg_path():
 return ' '.join('M '+' L '.join(f'{x:g},{y:g}' for x,y in pts)+' Z' for pts in normalized)
path_data=svg_path()
svg=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 {height:.3f}" role="img" aria-label="Max logo"><path fill="currentColor" fill-rule="evenodd" d="{path_data}"/></svg>\n'
(BRAND/'Max_Logo.svg').write_text(svg)
(BRAND/'Max_Logo_Path.json').write_text(json.dumps({'width':1000,'height':round(height,3),'contours':normalized},indent=2)+'\n')

def render(output, size, color='#111111', background=None, mark_width=None):
 width_px,height_px=size
 mark_width=mark_width or width_px
 mark_height=mark_width*height/1000
 x=(width_px-mark_width)/2;y=(height_px-mark_height)/2
 pdf=BRAND/'logo-render.pdf'
 c=canvas.Canvas(str(pdf),pagesize=size)
 if background:
  c.setFillColor(HexColor(background));c.rect(0,0,width_px,height_px,fill=1,stroke=0)
 c.setFillColor(HexColor(color))
 p=c.beginPath()
 for points in normalized:
  px,py=points[0];p.moveTo(x+px/1000*mark_width,height_px-(y+py/1000*mark_width))
  for px,py in points[1:]:p.lineTo(x+px/1000*mark_width,height_px-(y+py/1000*mark_width))
  p.close()
 c.drawPath(p,fill=1,stroke=0,fillMode=0);c.save()
 doc=fitz.open(pdf);pix=doc[0].get_pixmap(alpha=not bool(background));pix.save(str(output));doc.close()
 pdf.unlink()

render(BRAND/'Max_Logo_Black.png',(1200,660),mark_width=1120)
render(BRAND/'Max_Logo_White.png',(1200,660),color='#FFFFFF',mark_width=1120)
print('Traced contours:',len(normalized),'vertices:',sum(map(len,normalized)),'aspect ratio:',height/1000)
