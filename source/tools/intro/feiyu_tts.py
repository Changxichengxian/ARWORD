"""Render Mandarin directly with the author's cute F6 checkpoint and N01 prompt."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("model", "engine", "story", "output"):
        parser.add_argument("--"+name, required=True, type=Path)
    args = parser.parse_args()
    manifest = json.loads((args.model/"manifest.json").read_text(encoding="utf8"))
    style = manifest["styles"]["cute"]
    model_dir = args.model / manifest["base_model_dir"]
    checkpoint = args.model / style["llm_checkpoint"]
    reference = args.model / style["reference_audio"]
    if manifest["speaker_id"] != "feiyu" or style["candidate"] != "F6":
        raise ValueError("Expected the Feiyu F6 voice.")
    for path, expected in ((checkpoint, style["llm_sha256"]), (reference, style["reference_sha256"])):
        with path.open("rb") as f:
            if hashlib.file_digest(f, "sha256").hexdigest() != expected:
                raise ValueError(f"Incorrect voice asset: {path.name}")

    os.environ.update(HF_HUB_OFFLINE="1", TRANSFORMERS_OFFLINE="1", OMP_NUM_THREADS="4")
    sys.path.insert(0, str(args.engine))
    sys.path.append(str(args.engine/"third_party/Matcha-TTS"))
    # The existing project runtime has an isolated PyArrow 18 installation.
    arrow = Path.home()/".local/share/arword-feiyu/arrow18"
    if arrow.is_dir():
        sys.path.insert(0, str(arrow))
    import numpy as np
    import soundfile as sf
    import torch
    from cosyvoice.cli.cosyvoice import AutoModel
    from cosyvoice.utils.common import set_all_random_seed

    torch.set_num_threads(4)
    voice = AutoModel(model_dir=str(model_dir), fp16=False, load_trt=False, load_vllm=False)
    if not checkpoint.samefile(model_dir/"llm.pt"):
        weights = torch.load(checkpoint, map_location="cpu", weights_only=True)
        voice.model.llm.load_state_dict(weights, strict=True)
        del weights
    voice.model.llm.eval()
    params = manifest["inference"]
    prompt = params["prompt_prefix"] + style["reference_text"]
    tasks = json.loads(args.story.read_text(encoding="utf8"))
    args.output.mkdir(parents=True, exist_ok=True)
    with torch.inference_mode():
        for scene in tasks:
            if not scene.get("line"):
                continue
            set_all_random_seed(params["seed"])
            pieces = voice.inference_zero_shot(scene["line"], prompt, str(reference),
                                               speed=params["speed"], stream=False, text_frontend=True)
            signal = np.concatenate([p["tts_speech"][0].detach().cpu().numpy() for p in pieces])
            if len(signal) < voice.sample_rate*.2 or not np.isfinite(signal).all() or np.max(abs(signal)) < .005:
                raise ValueError(f"Invalid speech for {scene['shot']}")
            signal *= min(1., .98/np.max(abs(signal)))
            sf.write(args.output/(scene["shot"]+".wav"), signal, voice.sample_rate, subtype="PCM_16")
            print(f"{scene['shot']} {len(signal)/voice.sample_rate:.2f}s", flush=True)


if __name__ == "__main__":
    main()
