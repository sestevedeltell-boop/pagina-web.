"""Construye la escena y la guarda en villa.blend."""
import bpy, os, sys
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'scene.py')).read())
out = next((a for a in sys.argv[1:] if a.endswith('.blend')), os.path.join(os.getcwd(), 'villa.blend'))
bpy.ops.wm.save_as_mainfile(filepath=out)
