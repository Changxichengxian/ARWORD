"""Rebuild the final opaque, continuously skinned D character and editable Blender source.

Blender --background --python source/tools/make_builder.py
No intermediate blockout, prior .blend file, or files under work/ are needed.
The study generator is shared so the selected geometry remains reproducible.
"""
from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).with_name('make_character_studies.py')),init_globals={'INSTALL_D':True})
