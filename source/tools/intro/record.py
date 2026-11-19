"""Film a local portrait introduction from ARWORD's real Godot scenes."""
import argparse
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import wave
import zipfile

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parents[1]
ROOT = SOURCE.parent
VOICE = ROOT / "work/qa142"
STORY = HERE / "story.json"
MUSIC = SOURCE / "assets/music/glass_orbit.ogg"
STUDY_PACK = SOURCE / "assets/characters/feiyu-cute-v1.arvoice"
RATE = 48000


def locate(explicit, command, candidates):
    for item in [explicit] if explicit else [shutil.which(command), *candidates]:
        if item and Path(item).is_file():
            return Path(item).resolve()
    raise ValueError(f"Could not find {command}. Set --{command} to its executable.")


def wsl_path(path):
    path = Path(path).resolve()
    if not re.fullmatch("[A-Za-z]:", path.drive):
        raise ValueError(f"Use a Windows drive path for voice conversion: {path}")
    return f"/mnt/{path.drive[0].lower()}/" + "/".join(path.parts[1:])


def narrate(work, scenes, ffmpeg, args):
    print("正在生成大肥鱼的中文旁白……", flush=True)
    powershell = Path(os.environ["SystemRoot"]) / "System32/WindowsPowerShell/v1.0/powershell.exe"
    subprocess.run([powershell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                    HERE/"mandarin.ps1", "-Story", STORY, "-Destination", work], check=True)
    original, converted = work/"mandarin.zip", work/"feiyu.zip"
    with zipfile.ZipFile(original, "w") as archive:
        for scene in scenes:
            if "line" not in scene:
                continue
            shot = scene["shot"]
            take = subprocess.check_output([ffmpeg, "-v", "error", "-i", work/f"{shot}.wav",
                                            "-c:a", "libmp3lame", "-q:a", "1", "-f", "mp3", "-"])
            archive.writestr(f"audio/{shot}.mp3", take)

    # Reuse the exact reference/checkpoint validation and conversion used by the personal voice pack.
    converter_args = [SOURCE/"tools/make_study_voice.py", "--input", original, "--output", converted,
                      "--reference", args.reference.resolve(), "--converter", args.converter.resolve()]
    if args.voice_python:
        command = [args.voice_python, *converter_args]
    else:
        command = ["wsl.exe", "-d", args.distro, "--cd", "~", "--exec",
                   ".local/share/arword-feiyu/env/bin/python",
                   *[wsl_path(v) if isinstance(v, Path) else v for v in converter_args]]
    conversion = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=600)
    if conversion.returncode:
        raise RuntimeError("大肥鱼音色转换失败。\n" + conversion.stdout.decode("utf8", errors="replace")[-3500:])
    clips = {}
    with zipfile.ZipFile(converted) as archive:
        index = json.loads(archive.read("index.json"))
        if index["voice"] != "Feiyu Cute N01" or index["tracks"] != len(scenes_with_lines(scenes)):
            raise ValueError("Unexpected voice pack.")
        for scene in scenes_with_lines(scenes):
            shot = scene["shot"]
            clips[shot] = decode_voice(ffmpeg, archive.read(f"audio/{shot}.mp3"))
    words = {s["word"] for s in scenes if s.get("word")}
    if words:
        lexicon = json.loads((SOURCE/"assets/wordbooks/lexicon.json").read_text("utf8"))
        paths = {w["id"]: w["audio"] for w in lexicon}
        with zipfile.ZipFile(STUDY_PACK) as pack:
            for word in words:
                clips[("word", word)] = decode_voice(ffmpeg, pack.read(paths[word]))
    return clips


def decode_voice(ffmpeg, encoded):
    pcm = subprocess.run(
        [ffmpeg, "-v", "error", "-i", "pipe:0", "-af",
         "silenceremove=start_periods=1:start_threshold=-55dB,loudnorm=I=-17:TP=-2:LRA=8",
         "-ar", str(RATE), "-ac", "1", "-f", "s16le", "-"],
        input=encoded, stdout=subprocess.PIPE, check=True).stdout
    if len(pcm) < RATE//4 or not any(pcm):
        raise ValueError("Empty speech recording.")
    return pcm


def scenes_with_lines(scenes):
    return [s for s in scenes if s.get("line")]


def stamp(seconds):
    ticks = round(seconds * 100)
    return f"{ticks//360000}:{ticks//6000%60:02}:{ticks//100%60:02}.{ticks%100:02}"


def timeline(work, scenes, clips, fps, width):
    frame = 0
    audio = bytearray()
    events = []

    def caption(start, end, style, text):
        events.append(f"Dialogue: 0,{stamp(start)},{stamp(end)},{style},,0,0,0,,{text}")

    for scene in scenes:
        shot = scene["shot"]
        start = frame / fps
        seconds = scene["seconds"]
        if shot in clips:
            clip = clips[shot]
            at = scene["at"]
            duration = len(clip) / (2*RATE)
            offset = round((start+at)*RATE)*2
            audio.extend(bytes(offset-len(audio)))
            audio.extend(clip)
            seconds = max(seconds, at+duration+.55)
            caption(start+at, start+at+duration, "Card" if shot == "word" else "Voice",
                    wrap_caption(scene["line"]))
            if scene.get("word"):
                # Leave room to hear the real in-app pronunciation before the answer is revealed.
                audio.extend(bytes(round(.35*RATE)*2))
                audio.extend(clips[("word", scene["word"])])
                seconds = max(seconds, len(audio)/(2*RATE)-start+1.35)
        scene["frames"] = math.ceil(seconds*fps)
        if shot == "opening":
            caption(.45, seconds-.45, "Title", r"{\fad(300,350)}ARWORD")
            caption(.8, seconds-.45, "Deck", r"{\fad(300,350)}在小星球上背单词")
        frame += scene["frames"]
    audio.extend(bytes(round(frame/fps*RATE)*2-len(audio)))
    with wave.open(str(work/"voice.wav"), "wb") as wav:
        wav.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        wav.writeframes(audio)
    # Fixed design coordinates for all 9:16 outputs. The card needs its own clear band.
    header = """[Script Info]
ScriptType: v4.00+
PlayResX: 720
PlayResY: 1280
WrapStyle: 0
ScaledBorderAndShadow: yes
[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Voice,Microsoft YaHei,37,&H00FFFFFF,&H00FFFFFF,&H330E131B,&H99000000,0,0,0,0,100,100,0,0,1,2.2,1,2,32,32,87,1
Style: Card,Microsoft YaHei,34,&H00FFFFFF,&H00FFFFFF,&H330E131B,&H99000000,0,0,0,0,100,100,0,0,1,2.2,1,8,34,34,142,1
Style: Title,Segoe UI Semibold,58,&H00FFFFFF,&H00FFFFFF,&H66000000,&H99000000,0,0,0,0,100,100,5,0,1,1,0,2,30,30,191,1
Style: Deck,Microsoft YaHei,28,&H00F4F4F4,&H00FFFFFF,&H66000000,&H99000000,0,0,0,0,100,100,1,0,1,1,0,2,30,30,152,1
[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""
    (work/"subtitles.ass").write_text(header+"\n".join(events)+"\n", encoding="utf-8-sig")
    plan = dict(width=width, height=width*16//9, fps=fps, scenes=scenes)
    (work/"plan.json").write_text(json.dumps(plan, ensure_ascii=False), encoding="utf8")
    return frame


def wrap_caption(line):
    if len(line) <= 17:
        return line
    breaks = [i+1 for i, char in enumerate(line[:-1]) if char in "，。？！"]
    pivot = min(breaks, key=lambda i: abs(i-len(line)/2)) if breaks else len(line)//2
    return line[:pivot] + r"\N" + line[pivot:]


def capture(work, engine, count, fps, width):
    profile = work/"profile"
    profile.mkdir()
    command = [engine, "--path", SOURCE, "--position", "-3000,-2000", "--resolution",
               f"{width}x{width*16//9}", "--audio-driver", "Dummy", "--fixed-fps", str(fps),
               "--log-file", work/"capture.log", "--script", "res://tools/intro/record.gd",
               "--", "--qa", "--qa-with-cast", "--qa-avatar-scope=intro", "--capture-dir="+str(work)]
    subprocess.run(command, env={**os.environ, "APPDATA": str(profile), "LOCALAPPDATA": str(profile)},
                   check=True, timeout=1800)
    log = (work/"capture.log").read_text("utf8", errors="replace")
    if (f"INTRO_COMPLETE {count}\n" not in log or "SCRIPT ERROR" in log or "SHADER ERROR" in log
            or len(list(work.glob("*.jpg"))) != count):
        raise ValueError("Incomplete recording. " + log[-1500:])


def encode(work, output, ffmpeg, fps, frames):
    seconds = frames/fps
    graph = (f"[2:a]volume=0.27,afade=t=in:d=1,afade=t=out:st={seconds-2}:d=2[m];"
             "[1:a]asplit=2[voice][key];[m][key]sidechaincompress=threshold=0.025:"
             "ratio=5:attack=18:release=380[bed];[bed][voice]amix=inputs=2:"
             "duration=shortest:normalize=0,alimiter=limit=0.94[a]")
    movie = work/"intro.mp4"
    subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
                    "-framerate", str(fps), "-i", "%06d.jpg", "-i", "voice.wav",
                    "-stream_loop", "-1", "-i", MUSIC, "-filter_complex", graph,
                    "-map", "0:v", "-map", "[a]", "-vf", "ass=subtitles.ass",
                    "-c:v", "libx264", "-crf", "17", "-preset", "medium", "-pix_fmt", "yuv420p",
                    "-c:a", "aac", "-b:a", "192k", "-ar", str(RATE), "-ac", "2",
                    "-movflags", "+faststart", "-t", str(seconds), movie], cwd=work, check=True)
    # Decode both streams all the way through before replacing an earlier good take.
    verify = subprocess.check_output([ffmpeg, "-v", "error", "-xerror", "-progress", "pipe:1",
                                      "-i", movie, "-map", "0:v:0", "-map", "0:a:0", "-f", "null", "-"])
    if not re.search(rb"(?m)^frame=\s*"+str(frames).encode()+rb"\s*$", verify):
        raise ValueError("Encoded frame count does not match the script.")
    os.replace(movie, output)
    print(f"{output}  ({seconds:.1f} s, {frames} frames)", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT/"outputs/应用介绍/ARWORD-介绍.mp4")
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--ffmpeg", type=Path)
    parser.add_argument("--width", type=int, choices=[360, 540, 720, 1080], default=720)
    parser.add_argument("--fps", type=int, choices=[12, 24, 30], default=24)
    parser.add_argument("--reference", type=Path, default=VOICE/"feiyu/references/cute_N01.wav")
    parser.add_argument("--converter", type=Path, default=VOICE/"converter")
    parser.add_argument("--voice-python", type=Path, help="Native Python with the OpenVoice CUDA dependencies")
    parser.add_argument("--distro", default="Ubuntu")
    args = parser.parse_args()
    engine = locate(args.godot, "godot", sorted((ROOT/"work/tools3d/godot").glob("*_console.exe")))
    ffmpeg = locate(args.ffmpeg, "ffmpeg", [r"C:\App\Fun\steam\steamapps\common\ShareX\ShareX\ffmpeg.exe",
                                          r"C:\App\Work\BBDown\ffmpeg.exe"])
    for required in (args.reference, args.converter/"checkpoint.pth", MUSIC,
                     SOURCE/"assets/characters/deepseek.vrm"):
        if not required.is_file():
            parser.error(f"Missing local recording asset: {required}")
    output = args.output.resolve()
    if output.suffix.lower() != ".mp4":
        parser.error("--output must end in .mp4")
    output.parent.mkdir(parents=True, exist_ok=True)
    scenes = json.loads(STORY.read_text("utf8"))
    with tempfile.TemporaryDirectory(prefix="record-", dir=output.parent) as staging:
        work = Path(staging)
        clips = narrate(work, scenes, ffmpeg, args)
        frames = timeline(work, scenes, clips, args.fps, args.width)
        print("配音完成，开始拍摄。", flush=True)
        capture(work, engine, frames, args.fps, args.width)
        print("正在混音、压制和检查成片……", flush=True)
        encode(work, output, ffmpeg, args.fps, frames)


if __name__ == "__main__":
    main()
