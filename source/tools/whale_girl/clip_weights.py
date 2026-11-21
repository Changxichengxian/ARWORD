"""Export Blender's face and hair drivers as ordinary glTF animation weights."""
import argparse
import json
import struct
from pathlib import Path


def illustrated(name):
    return name.startswith(("Pigment ", "Woven ", "Painted complexion", "costume-and-face",
                            "Indigo silk and glacier blue", "Roasted plum lash", "Indigo brow"))


def ease(value):
    t = max(0, min(1, value))
    return t*t*(3-2*t)


def export(filename, meal_path, destination=None, preview=False):
    data = Path(filename).read_bytes()
    json_size = struct.unpack_from("<I", data, 12)[0]
    model = json.loads(data[20:20 + json_size])
    for mat in model["materials"]:
        if illustrated(mat["name"]):
            mat.setdefault("extensions", {})["KHR_materials_unlit"] = {}
            mat.pop("emissiveTexture", None)
            mat.pop("emissiveFactor", None)
    if "KHR_materials_unlit" not in model.setdefault("extensionsUsed", []):
        model["extensionsUsed"].append("KHR_materials_unlit")
    binary = bytearray(data[28 + json_size:][:model["buffers"][0]["byteLength"]])
    meal = json.loads(Path(meal_path).read_text(encoding="utf8"))

    def scalars(values, time=False):
        binary.extend(bytes(-len(binary) % 4))
        raw = struct.pack(f"<{len(values)}f", *values)
        view = {"buffer": 0, "byteOffset": len(binary), "byteLength": len(raw)}
        binary.extend(raw)
        model["bufferViews"].append(view)
        accessor = {"bufferView": len(model["bufferViews"])-1, "componentType": 5126,
                    "count": len(values), "type": "SCALAR"}
        if time:
            accessor.update(min=[min(values)], max=[max(values)])
        model["accessors"].append(accessor)
        return len(model["accessors"])-1

    durations = {"IslandIdle": 5, "BalanceBasin": 6, "RiceBreak": 7}
    for clip in model["animations"]:
        name = clip["name"]
        times = [i / 12 for i in range(durations[name]*12+1)]
        if not any(c["target"]["path"] == "weights" for c in clip["channels"]):
            clock = scalars(times, time=True)
            for idx, node in enumerate(model["nodes"]):
                if "mesh" not in node:
                    continue
                keys = model["meshes"][node["mesh"]].get("extras", {}).get("targetNames", [])
                if not keys:
                    continue
                values = []
                for i, t in enumerate(times):
                    jaw, blink, _ = meal[i] if name == "RiceBreak" else (.015, ease((t-2.08)/.085)*(1-ease((t-2.25)/.14)), 0)
                    tuck = ease((t-.70)/.48)*(1-ease((t-5.13)/.52)) if name == "BalanceBasin" else 0
                    weights = {"ih": jaw, "blink": blink, "BasinSeat": tuck, "BasinTuck": tuck}
                    values.extend(weights.get(key, 0) for key in keys)
                clip["samplers"].append({"input": clock, "output": scalars(values), "interpolation": "LINEAR"})
                clip["channels"].append({"sampler": len(clip["samplers"])-1, "target": {"node": idx, "path": "weights"}})
        if preview and name == "IslandIdle":
            # Neutral stance for model viewers that do not autoplay animation.
            for channel in clip["channels"]:
                target = channel["target"]
                components = {"scale": 3, "translation": 3, "rotation": 4}.get(target["path"])
                if not components:
                    continue
                accessor = model["accessors"][clip["samplers"][channel["sampler"]]["output"]]
                view = model["bufferViews"][accessor["bufferView"]]
                offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
                model["nodes"][target["node"]][target["path"]] = struct.unpack_from(f"<{components}f", binary, offset)
    model["buffers"][0]["byteLength"] = len(binary)
    binary.extend(bytes(-len(binary) % 4))
    encoded = json.dumps(model, ensure_ascii=False, separators=(",", ":")).encode("utf8")
    encoded += b" " * (-len(encoded) % 4)
    output = struct.pack("<4sIIII", b"glTF", 2, 28+len(encoded)+len(binary), len(encoded), 0x4e4f534a)
    output += encoded + struct.pack("<I4s", len(binary), b"BIN\0") + binary
    Path(destination or filename).write_bytes(output)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("model", type=Path)
    parser.add_argument("--preview", type=Path)
    args = parser.parse_args()
    export(args.model, args.model.with_name("whale_meal.json"), args.preview, bool(args.preview))
