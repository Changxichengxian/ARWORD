"""Create the private offline English pack from whole existing utterances.

Inputs are a ZIP of the project's English MP3 paths, the authorized cute N01
synthetic reference, and the official MyShell OpenVoice V2 converter source
and checkpoint. The voice reference, weights and rendered pack are private.
Run on the build machine. Mobile playback only reads individual MP3 entries.
"""
import argparse
import hashlib
import io
import json
import sys
import zipfile
from pathlib import Path

import numpy as np
import soundfile as sf
import soxr
import torch
from torch.nn.utils.rnn import pad_sequence

REFERENCE_SHA = 'cefa06b7f45479130169d154f84a32bc89d90585b7de50f96e36533c5ebe819e'
CONVERTER_SHA = '9652c27e92b6b2a91632590ac9962ef7ae2b712e5c5b7f4c34ec55ee2b37ab9e'
CLARITY_BLEND = {'audio/word_retain.mp3': .2, 'audio/work05_cue.mp3': .35}


def main():
    parser = argparse.ArgumentParser(__doc__)
    for name in ['input', 'reference', 'converter', 'output']:
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--sample', action='store_true')
    args = parser.parse_args()
    checkpoint = args.converter / 'checkpoint.pth'
    for file, expected in [(args.reference, REFERENCE_SHA), (checkpoint, CONVERTER_SHA)]:
        with file.open('rb') as stream:
            assert hashlib.file_digest(stream, 'sha256').hexdigest() == expected, file
    sys.path.insert(0, str(args.converter.resolve()))
    from openvoice.models import SynthesizerTrn
    from openvoice.mel_processing import spectrogram_torch

    cfg = json.loads((args.converter / 'config.json').read_text())
    d = cfg['data']
    rate, hop = d['sampling_rate'], d['hop_length']
    model = SynthesizerTrn(0, d['filter_length'] // 2 + 1, n_speakers=0, **cfg['model'])
    state = torch.load(checkpoint, map_location='cpu', weights_only=True)['model']
    missing, _ = model.load_state_dict(state, strict=False)
    assert not missing, missing
    model = model.eval().cuda()
    torch.manual_seed(42)
    torch.set_num_threads(2)

    def spec(file):
        samples, sr = sf.read(file, dtype='float32', always_2d=True)
        samples = samples.mean(axis=1)
        if sr != rate:
            samples = soxr.resample(samples, sr, rate)
        y = torch.from_numpy(samples).cuda()[None, :]
        return spectrogram_torch(y, d['filter_length'], rate, hop, d['win_length'], center=False)[0]

    def convert(batch, target):
        lengths = torch.tensor([s.size(-1) for _, s in batch], device='cuda')
        spectra = pad_sequence([s.T for _, s in batch], batch_first=True).transpose(1, 2)
        source_voice = torch.cat([model.ref_enc(s.T.unsqueeze(0)) for _, s in batch]).unsqueeze(-1)
        wav = model.voice_conversion(spectra, lengths, source_voice, target.expand(len(batch), -1, -1), tau=.3)[0][:, 0].cpu().numpy()
        outputs = {}
        for i, (name, s) in enumerate(batch):
            samples = wav[i, :s.size(-1) * hop]
            assert np.isfinite(samples).all() and np.max(np.abs(samples)) > .012, name
            samples *= min(1., .94 / np.max(np.abs(samples)))
            clip = io.BytesIO()
            sf.write(clip, samples, rate, format='MP3', bitrate_mode='VARIABLE', compression_level=.65)
            outputs[name] = clip.getvalue()
        return outputs

    args.output.parent.mkdir(parents=True, exist_ok=True)
    staging = args.output.with_suffix('.part')
    with torch.inference_mode(), zipfile.ZipFile(args.input) as original, zipfile.ZipFile(staging, 'w') as output:
        target = model.ref_enc(spec(args.reference).T.unsqueeze(0)).unsqueeze(-1)
        names = original.namelist()
        if args.sample:
            names = ['audio/word_retain.mp3', 'audio/word_replace.mp3', 'audio/work00_cue.mp3', 'audio/work00_full.mp3']
        groups = {}
        for name in names:
            assert name.endswith('.mp3') and name.startswith(('audio/', 'wordbooks/audio/')) and '..' not in name
            digest = hashlib.sha256(original.read(name)).digest()
            groups.setdefault(digest, []).append(name)
        blends = {hashlib.sha256(original.read(p)).digest(): gain for p, gain in CLARITY_BLEND.items() if p in names}
        pending = []
        def flush():
            if not pending:
                return
            for digest, mp3 in convert(pending, target).items():
                if digest in blends:
                    mp3 = restore_articulation(original.read(groups[digest][0]), mp3, blends[digest])
                for name in groups[digest]:
                    output.writestr(name, mp3)
            pending.clear()
        for index, (digest, paths) in enumerate(groups.items()):
            s = spec(io.BytesIO(original.read(paths[0])))
            if s.size(-1) > 350:
                flush()
            pending.append((digest, s))
            if len(pending) == 6 or s.size(-1) > 350:
                flush()
            if index % 500 == 0:
                print(f'{index}/{len(groups)} recordings', flush=True)
        flush()
        output.writestr('index.json', json.dumps({'format': 1, 'voice': 'Feiyu Cute N01',
            'reference_sha256': REFERENCE_SHA, 'converter_sha256': CONVERTER_SHA,
            'tracks': len(names), 'source': '星落落_oi / Esmerubphire', 'use': 'personal, noncommercial'}))
    with zipfile.ZipFile(staging) as pack:
        assert pack.testzip() is None and len(pack.namelist()) == len(names) + 1
    staging.replace(args.output)
    print('Created', args.output, len(names), 'English tracks', flush=True)


def restore_articulation(original, converted, amount):
    """Keep part of the source take for a short onset or an unstressed conjunction."""
    source, source_rate = sf.read(io.BytesIO(original), dtype='float32')
    changed, rate = sf.read(io.BytesIO(converted), dtype='float32')
    if source_rate != rate:
        source = soxr.resample(source, source_rate, rate)
    length = min(len(source), len(changed))
    mixed = changed[:length] * (1 - amount) + source[:length] * amount
    result = io.BytesIO()
    sf.write(result, mixed, rate, format='MP3', bitrate_mode='VARIABLE', compression_level=.65)
    return result.getvalue()


if __name__ == '__main__':
    main()

