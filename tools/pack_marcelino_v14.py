"""Compatibility entry point: always pack the corrected original-photo revision.

The old v14 source is retained as history and must not replace the corrected face.
"""
from pack_marcelino_face_v15 import effects, fighters

if __name__ == "__main__":
    effects()
    fighters()
