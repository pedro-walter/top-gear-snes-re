import sys
from PIL import Image
n=32
ims=[Image.open('out/ge%d_pos.png'%e).crop((60,0,256,56)) for e in range(n)]
w,h=ims[0].size
S=Image.new('RGB',(w*4,h*8))
for i,im in enumerate(ims): S.paste(im,((i%4)*w,(i//4)*h))
S.save('out/ge_sheet.png')
