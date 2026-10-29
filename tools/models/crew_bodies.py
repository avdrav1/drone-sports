"""Story 20.1: crew bodies from Kenney's Mini Characters (CC0).

Reads the pack's GLB files (data only, nothing in the download runs) and
writes each body to data/models/crew/ with its recolourable parts moved into
the colormap's unused top row, one cell per role, so a CrewLook can paint
skin, hair, top, bottom and shoes (scenes/crew/crew_body.gdshader). Every
other part (eyes, glasses, belts, soles) keeps the pack's colour.

Usage: python3 -I tools/models/crew_bodies.py "<pack>/Models/GLB format" data/models/crew
"""
import collections
import json
import os
import shutil
import struct
import sys

# The bodies the crew wear, by the pack's file name, with the colormap column
# of their skin (the head box and the hands; row 3).
BODIES = {"character-female-b": 15, "character-female-c": 11, "character-female-d": 15,
	"character-female-e": 15, "character-female-f": 15, "character-male-a": 13,
	"character-male-b": 15, "character-male-d": 15, "character-male-f": 11}
# Role cells in the colormap's top row (crew_look.gd ROLES has the same order).
SKIN, HAIR, TOP, BOTTOM, SHOES = 0, 1, 2, 3, 4
COLS, ROWS = 16, 4
SHOE_TOP = 0.1  # model units: leg faces below this are shoes

CT = {5126: ("f", 4), 5123: ("H", 2), 5121: ("B", 1), 5125: ("I", 4)}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read_glb(path):
	b = open(path, "rb").read()
	jlen = struct.unpack_from("<I", b, 12)[0]
	j = json.loads(b[20:20 + jlen])
	blen = struct.unpack_from("<I", b, 20 + jlen)[0]
	return j, bytearray(b[28 + jlen:28 + jlen + blen])


def write_glb(path, j, binb):
	js = json.dumps(j, separators=(",", ":")).encode()
	js += b" " * (-len(js) % 4)
	binb = bytes(binb) + b"\0" * (-len(binb) % 4)
	total = 12 + 8 + len(js) + 8 + len(binb)
	with open(path, "wb") as f:
		f.write(struct.pack("<III", 0x46546C67, 2, total))
		f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
		f.write(struct.pack("<II", len(binb), 0x004E4942) + binb)


def view(j, i):
	a = j["accessors"][i]
	v = j["bufferViews"][a["bufferView"]]
	fmt, size = CT[a["componentType"]]
	n = NC[a["type"]]
	off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
	return a, fmt, n, off, v.get("byteStride", size * n)


def read(j, binb, i):
	a, fmt, n, off, stride = view(j, i)
	return [struct.unpack_from("<" + fmt * n, binb, off + k * stride) for k in range(a["count"])]


def cell(uv):
	return (min(int(uv[0] * COLS), COLS - 1), min(int(uv[1] * ROWS), ROWS - 1))


def is_eye(p):
	# The pack's eyes sit flat on the face's front, both sides of the nose line.
	return 0.15 < p[2] < 0.165 and 0.39 < p[1] < 0.54 and abs(p[0]) < 0.13


def crown(j, binb):
	"""Top of the hair over the front half of the head, where a hat sits."""
	m = next(i for i, m in enumerate(j["meshes"]) if m["name"] == "head-mesh")
	pos = read(j, binb, j["meshes"][m]["primitives"][0]["attributes"]["POSITION"])
	return max(p[1] for p in pos if p[2] > 0.0 and abs(p[0]) < 0.12)


def roles_for(j, binb, skin):
	"""{mesh index: {vertex: role}} for the faces that take a look's colour."""
	joints = [j["nodes"][k]["name"] for k in j["skins"][0]["joints"]]
	meshes = {}
	for mi, m in enumerate(j["meshes"]):
		pr = m["primitives"][0]
		at = pr["attributes"]
		uv = read(j, binb, at["TEXCOORD_0"])
		pos = read(j, binb, at["POSITION"])
		jn = read(j, binb, at["JOINTS_0"])
		wt = read(j, binb, at["WEIGHTS_0"])
		idx = [t[0] for t in read(j, binb, pr["indices"])]
		bone = [joints[jn[k][max(range(4), key=lambda q: wt[k][q])]] for k in range(len(pos))]
		tris = [idx[t:t + 3] for t in range(0, len(idx), 3)]
		meshes[m["name"]] = (mi, uv, pos, bone, tris)
	out = {}
	for name, (mi, uv, pos, bone, tris) in meshes.items():
		groups = collections.defaultdict(list)
		for t in tris:
			c = cell(uv[t[0]])
			if c == skin:
				groups["skin"].append(t)
			elif name == "head-mesh":
				if not (c == (1, 3) and all(is_eye(pos[k]) for k in t)):
					groups["hair"].append(t)
			elif all(bone[k].startswith("leg") for k in t):
				low = max(pos[k][1] for k in t) <= SHOE_TOP
				groups["shoes" if low else "bottom"].append(t)
			else:
				groups["top"].append(t)
		role = {"skin": SKIN, "hair": HAIR, "top": TOP, "bottom": BOTTOM, "shoes": SHOES}
		verts = {}
		for g, ts in groups.items():
			# Only the group's main colour is recoloured; a belt, badge or
			# headband in another cell keeps the pack's colour.
			main = collections.Counter(cell(uv[t[0]]) for t in ts).most_common(1)[0][0]
			for t in ts:
				if g == "skin" or cell(uv[t[0]]) == main:
					for k in t:
						# A few vertices at a shoe's top edge are shared with the
						# trouser leg; the first role wins.
						verts.setdefault(k, role[g])
		out[mi] = verts
	return out


def main():
	src, dst = sys.argv[1], sys.argv[2]
	os.makedirs(dst, exist_ok=True)
	for body, col in BODIES.items():
		j, binb = read_glb(os.path.join(src, body + ".glb"))
		for mi, verts in roles_for(j, binb, (col, 3)).items():
			a, fmt, n, off, stride = view(j, j["meshes"][mi]["primitives"][0]["attributes"]["TEXCOORD_0"])
			for k, r in verts.items():
				u, v = struct.unpack_from("<ff", binb, off + k * stride)
				fu, fv = u * COLS % 1.0, v * ROWS % 1.0
				struct.pack_into("<ff", binb, off + k * stride, (r + fu) / COLS, fv / ROWS)
		j["images"] = [{"uri": "colormap.png", "name": "colormap"}]
		write_glb(os.path.join(dst, body + ".glb"), j, binb)
		print(body, "crown %.3f" % crown(j, binb))
	shutil.copyfile(os.path.join(src, "Textures", "colormap.png"), os.path.join(dst, "colormap.png"))


if __name__ == "__main__":
	main()
