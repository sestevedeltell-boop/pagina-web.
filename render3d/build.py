"""Construye la escena y la guarda en villa.blend."""
import bpy, os
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'scene.py')).read())
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(os.getcwd(), 'villa.blend'))
