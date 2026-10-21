"""Trace the supplied logo into the shared SwiftUI vector and branding assets.

No generative redraw: contours follow the reference. Requires numpy, matplotlib,
Pillow, reportlab and PyMuPDF. The original JPEG remains unchanged.
"""
from pathlib import Path
import json, shutil
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

# The same contour data is used by the app and its widget target.
arrays=',\n'.join('        ['+', '.join(f'CGPoint(x: {x:g}, y: {y:g})' for x,y in pts)+']' for pts in normalized)
swift='''import SwiftUI

/// Max's supplied brand mark, traced from branding/Max_Logo_Reference.jpeg.
/// The detached lower-right curve and ring opening are intentional.
/// Kept in code so the app and widget share the exact same scalable artwork.
struct MaxLogoView: View {
    var color: Color = .white
    var width: CGFloat = 180
    static let aspectRatio: CGFloat = HEIGHT / 1000

    var body: some View {
        MaxBrandShape()
            .fill(color, style: FillStyle(eoFill: true))
            .frame(width: width, height: width * Self.aspectRatio)
            .accessibilityLabel("Max")
    }
}

private struct MaxBrandShape: Shape {
    private static let contours: [[CGPoint]] = [
ARRAYS
    ]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for contour in Self.contours {
            guard let first = contour.first else { continue }
            func point(_ value: CGPoint) -> CGPoint {
                CGPoint(x: rect.minX + value.x / 1000 * rect.width,
                        y: rect.minY + value.y / HEIGHT * rect.height)
            }
            path.move(to: point(first))
            for value in contour.dropFirst() { path.addLine(to: point(value)) }
            path.closeSubpath()
        }
        return path
    }
}
'''.replace('HEIGHT',f'{height:.3f}').replace('ARRAYS',arrays)
(ROOT/'ios-swift/Sources/Max/Components/MaxLogoView.swift').write_text(swift)

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
render(ROOT/'ios-swift/Sources/Max/Assets.xcassets/AppIcon.appiconset/AppIcon.png',(1024,1024),background='#FAFCFD',mark_width=700)
launch=ROOT/'ios-swift/Sources/Max/Assets.xcassets/LaunchLogo.imageset'
render(launch/'LaunchLogo.png',(600,320),mark_width=560)
render(launch/'LaunchLogoDark.png',(600,320),color='#FFFFFF',mark_width=560)
contents={'images':[{'idiom':'universal','filename':'LaunchLogo.png','scale':'1x'},{'idiom':'universal','filename':'LaunchLogoDark.png','scale':'1x','appearances':[{'appearance':'luminosity','value':'dark'}]}],'info':{'author':'xcode','version':1}}
(launch/'Contents.json').write_text(json.dumps(contents,indent=2)+'\n')
print('Traced contours:',len(normalized),'vertices:',sum(map(len,normalized)),'aspect ratio:',height/1000)
