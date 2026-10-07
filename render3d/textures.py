import numpy as np, math, random
from PIL import Image, ImageDraw, ImageFilter
import os
OUT=os.path.join(os.path.dirname(os.path.abspath(__file__)), 'tex') + '/'
rng=np.random.default_rng(7); random.seed(7)

def fnoise(h,w,beta,seed=None,ax=1.0,ay=1.0):
    r=np.random.default_rng(seed)
    wn=r.standard_normal((h,w))
    ky=np.fft.fftfreq(h)[:,None]*h*ay; kx=np.fft.fftfreq(w)[None,:]*w*ax
    k=np.sqrt(kx**2+ky**2); k[0,0]=1
    f=np.fft.ifft2(np.fft.fft2(wn)/k**beta).real
    f-=f.min(); f/=f.max(); return f

def normal_from_height(hm,strength):
    dx=(np.roll(hm,-1,1)-np.roll(hm,1,1))*strength
    dy=(np.roll(hm,-1,0)-np.roll(hm,1,0))*strength
    n=np.dstack([-dx,dy,np.ones_like(hm)]); n/=np.linalg.norm(n,axis=2,keepdims=True)
    return Image.fromarray(((n*.5+.5)*255).astype(np.uint8))

def save_rgb(a,name,q=88):
    Image.fromarray(np.clip(a,0,255).astype(np.uint8)).save(OUT+name,quality=q)

def lerpc(c1,c2,t): return np.array(c1)[None,None,:]*(1-t[...,None])+np.array(c2)[None,None,:]*t[...,None]

# ---- césped ----
N=1024
patch=fnoise(N,N,1.6,1); fine=fnoise(N,N,0.4,2); blades=fnoise(N,N,0.9,3,ax=1,ay=.25)
t=np.clip(.45*patch+.35*fine+.2*blades,0,1)
g=lerpc((46,88,26),(118,158,58),t)
g+= (fnoise(N,N,0.2,4)[...,None]-.5)*28*np.array([.6,1,.3])
save_rgb(g,'grass.jpg')
normal_from_height(.6*fine+.4*blades,6).save(OUT+'grass_n.jpg',quality=88)

# ---- tarima de ipe ----
N=1024; rows=8; ph=N//rows
img=np.zeros((N,N,3)); hgt=np.ones((N,N)); rough=np.zeros((N,N))
grain=fnoise(N,N,1.2,5,ax=.06,ay=1.0)
fine=fnoise(N,N,0.6,6,ax=.15,ay=1.0)
for r in range(rows):
    y0=r*ph; base=np.array(random.choice([(112,56,33),(128,66,38),(98,50,30),(138,74,44),(120,62,40)]),float)
    joint=random.randint(0,N-1); joint2=(joint+random.randint(380,640))%N
    seg=np.zeros(N);
    for x in range(N):
        seg[x]=0 if ((x-joint)%N)<((joint2-joint)%N) else 1
    shade=np.where(seg==0,1.0,random.uniform(.88,1.1))
    sl=slice(y0,y0+ph)
    gtone=(grain[sl]-.5)*60+(fine[sl]-.5)*30
    img[sl]=base[None,None,:]*shade[None,:,None]+gtone[...,None]*np.array([1,.6,.4])
    img[y0:y0+3]*=.35; hgt[y0:y0+3]=0
    for jx in (joint,joint2):
        img[sl,jx%N]*=.45; hgt[sl,jx%N]=.2
rough=0.55+0.25*(1-hgt)+(fine-.5)*.15
save_rgb(img,'wood.jpg')
normal_from_height(hgt*0.6+grain*.4,4).save(OUT+'wood_n.jpg',quality=88)
save_rgb(np.dstack([rough*255]*3),'wood_r.jpg')

# ---- piedra en lajas (fachada) ----
N=1024
img=np.zeros((N,N,3)); hgt=np.zeros((N,N))
nz=fnoise(N,N,1.0,8); nz2=fnoise(N,N,0.5,9)
y=0
while y<N:
    hh=random.randint(26,60); hh=min(hh,N-y); x=random.randint(0,N)
    xs=0
    while xs<N:
        ww=random.randint(90,320); ww=min(ww,N-xs)
        tone=random.uniform(.78,1.08); base=np.array(random.choice([(206,196,176),(188,180,166),(214,205,188),(170,162,150),(196,184,160)]))*tone
        ys=slice(y+2,y+hh-2); xsl=np.arange(xs+2,xs+ww-2); xsl=(xsl+x)%N
        img[ys][:,xsl]=base
        hgt[ys][:,xsl]=.7+random.uniform(-.15,.15)
        xs+=ww
    y+=hh
img=img*(0.85+0.3*nz2[...,None])+(nz[...,None]-.5)*30
img[hgt==0]=(70,66,60)
save_rgb(img,'stone.jpg')
normal_from_height(hgt+nz2*.3,5).save(OUT+'stone_n.jpg',quality=88)

# ---- porcelánico gran formato ----
N=1024
nz=fnoise(N,N,1.1,11); vein=fnoise(N,N,1.4,12,ax=1,ay=.3)
img=lerpc((214,206,192),(232,226,214),np.clip(.6*nz+.4*vein,0,1))
for k in range(2):
    img[k*512:k*512+2,:]=(170,162,150); img[:,k*512:k*512+2]=(170,162,150)
save_rgb(img,'tile.jpg')

# ---- estuco blanco ----
N=512
nz=fnoise(N,N,1.3,13); f=fnoise(N,N,.3,14)
img=lerpc((236,234,228),(250,249,245),np.clip(.7*nz+.3*f,0,1))
save_rgb(img,'stucco.jpg')
normal_from_height(f,1.2).save(OUT+'stucco_n.jpg',quality=85)

# ---- gresite de piscina ----
N=512; n=16; s=N//n
img=np.zeros((N,N,3))
for i in range(n):
    for j in range(n):
        c=np.array(random.choice([(96,186,206),(118,200,216),(84,172,198),(132,210,222),(106,192,214)]))
        img[i*s:(i+1)*s,j*s:(j+1)*s]=c*random.uniform(.94,1.06)
        img[i*s:i*s+2,:]=(214,232,236); img[:,j*s:j*s+2]=(214,232,236)
save_rgb(img,'pooltile.jpg')

# ---- normales de agua ----
N=512
h=fnoise(N,N,2.0,15)*.7+fnoise(N,N,1.4,16)*.3
normal_from_height(h,22).save(OUT+'water_n.jpg',quality=90)

# ---- cáusticas ----
N=512
a=fnoise(N,N,1.8,17); b=fnoise(N,N,1.8,18)
c=np.maximum((1-np.abs(np.sin(a*math.pi*5)))**10,(1-np.abs(np.sin(b*math.pi*4)))**12)
c=np.clip(c*1.3,0,1)
Image.fromarray((c*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(.8)).convert('RGB').save(OUT+'caustics.jpg',quality=88)

# ---- grava / tierra exterior ----
N=512
nz=fnoise(N,N,.3,19); p=fnoise(N,N,1.5,20)
img=lerpc((196,186,168),(232,224,208),np.clip(.6*nz+.4*p,0,1))
save_rgb(img,'gravel.jpg')

# ---- hoja de palmera (RGBA) ----
W,H=512,1024
im=Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(im)
cx=W//2
for i in range(70):
    t=i/69; y=H-30-t*(H-60)
    L=(1-t)**.55*300*(0.5+0.5*math.sin(min(1,t*1.6+.1)*math.pi/2))+12
    for side in (-1,1):
        ang=math.radians(28+t*25)*1
        ex=cx+side*L*math.cos(ang); ey=y-L*math.sin(ang)
        wdt=7+6*(1-t)
        g=random.randint(0,30)
        col=(52+g,98+g+random.randint(0,20),34+g//2,255)
        nx,ny=-(ey-y),(ex-cx); ln=math.hypot(nx,ny) or 1; nx,ny=nx/ln*wdt*.5,ny/ln*wdt*.5
        d.polygon([(cx,y),(cx+nx*1.2+(ex-cx)*.5,y+ny*1.2+(ey-y)*.5),(ex,ey),(cx-nx*.4+(ex-cx)*.5,y-ny*.4+(ey-y)*.5)],fill=col)
d.line([(cx,H-10),(cx,20)],fill=(120,118,70,255),width=7)
im=im.filter(ImageFilter.GaussianBlur(.6))
im.save(OUT+'frond.png',optimize=True)

# ---- racimo de hojas para arbustos (RGBA) ----
W=256
im=Image.new('RGBA',(W,W),(0,0,0,0)); d=ImageDraw.Draw(im)
for i in range(140):
    x,y=random.gauss(W/2,W/5),random.gauss(W/2,W/5)
    if not (12<x<W-12 and 12<y<W-12): continue
    r=random.uniform(7,15); a=random.uniform(0,math.pi)
    g=random.randint(0,50)
    col=(40+g//2,82+g,30+g//3,255)
    pts=[(x+math.cos(a+k*math.pi/8)*r*(1 if k%8<4 else 1)*(abs(math.sin(k*math.pi/8))*.45+.55),y+math.sin(a+k*math.pi/8)*r*.5) for k in range(16)]
    d.polygon(pts,fill=col)
im.filter(ImageFilter.GaussianBlur(.4)).save(OUT+'leaves.png',optimize=True)

# ---- corteza de palmera ----
W,H=256,512
img=np.zeros((H,W,3))
nz=fnoise(H,W,1.0,21,ax=1,ay=.5)
for y in range(H):
    ring=(math.sin(y/H*math.pi*2*24)*.5+.5)**3
    img[y]=np.array((128,110,86))*(0.75+.25*ring)
img=img*(0.8+0.4*nz[...,None])
save_rgb(img,'bark.jpg')
print('ok')

# ---- cáusticas celulares (Voronoi F2-F1, periódicas) ----
N=384; P=70
pts=rng.random((P,2))
yy,xx=np.mgrid[0:N,0:N]/N
d1=np.full((N,N),9.0); d2=np.full((N,N),9.0)
for px,py in pts:
    dx=np.abs(xx-px); dx=np.minimum(dx,1-dx); dy=np.abs(yy-py); dy=np.minimum(dy,1-dy)
    dd=np.sqrt(dx*dx+dy*dy)
    d2=np.where(dd<d1,d1,np.minimum(d2,dd)); d1=np.minimum(d1,dd)
e=d2-d1
c=np.exp(-e*55)**1.4
c=np.clip(c*1.15,0,1)
Image.fromarray((c*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.0)).convert('RGB').save(OUT+'caustics.jpg',quality=88)

# ---- espuma de jacuzzi ----
W=256
im=Image.new('RGBA',(W,W),(255,255,255,0)); d=ImageDraw.Draw(im)
for i in range(420):
    a=random.uniform(0,2*math.pi); r=W/2*math.sqrt(random.random())*.95
    x,y=W/2+math.cos(a)*r,W/2+math.sin(a)*r; s=random.uniform(1.5,5)
    d.ellipse([x-s,y-s,x+s,y+s],fill=(255,255,255,random.randint(120,230)))
im.filter(ImageFilter.GaussianBlur(.7)).save(OUT+'foam.png',optimize=True)

# ---- sombras de contacto ----
W=128
yy,xx=np.mgrid[0:W,0:W]/(W-1)*2-1
r=np.sqrt(xx**2+yy**2); a=np.clip(1-r,0,1)**1.8
Image.fromarray(np.dstack([np.zeros((W,W))]*3+[a*255]).astype(np.uint8),'RGBA').save(OUT+'ao_blob.png')
lin=np.tile((np.linspace(1,0,W)**2.2)[:,None],(1,8))
Image.fromarray(np.dstack([np.zeros_like(lin)]*3+[lin*255]).astype(np.uint8),'RGBA').save(OUT+'ao_edge.png')

# césped normal más ligero
Image.open(OUT+'grass_n.jpg').resize((512,512),Image.LANCZOS).save(OUT+'grass_n.jpg',quality=82)
Image.open(OUT+'stone_n.jpg').resize((512,512),Image.LANCZOS).save(OUT+'stone_n.jpg',quality=82)
print('extra ok')
