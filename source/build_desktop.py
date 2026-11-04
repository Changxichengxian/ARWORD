"""Build an offline native Windows preview using the same Godot project as Android."""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess, tempfile, zipfile

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--godot',required=True);p.add_argument('--templates',required=True)
    p.add_argument('--output',required=True)
    args=p.parse_args();source=Path(__file__).resolve().parent
    output=Path(args.output).resolve();output.mkdir(parents=True,exist_ok=True)
    godot=Path(args.godot).resolve();templates=Path(args.templates).resolve()
    # Every build owns a new staging directory; user files and saves are never removed.
    with tempfile.TemporaryDirectory(prefix='little-tide-windows-',dir=output) as tmp:
        stage=Path(tmp).resolve()
        if stage.parent!=output:raise RuntimeError('Unexpected build staging path')
        project=stage/'project';project.mkdir()
        engine_dir=stage/'engine';engine_dir.mkdir();(engine_dir/'editor_data').mkdir();(engine_dir/'_sc_').touch()
        for binary in godot.parent.glob('Godot*win64*.exe'):shutil.copy2(binary,engine_dir/binary.name)
        engine=engine_dir/godot.name
        for name in ['assets','scripts']:shutil.copytree(source/name,project/name,ignore=shutil.ignore_patterns('*.blend','*.arvoice','.godot'))
        for name in ['project.godot','main.tscn']:shutil.copy2(source/name,project/name)
        # Seed only reproducible imported resources. Godot's import pass below
        # still checks source/settings hashes and rebuilds changed resources.
        # Never copy editor state, user saves or the script-class cache.
        imported=source/'.godot/imported'
        if imported.is_dir():shutil.copytree(imported,project/'.godot/imported')
        template=stage/'windows_release_x86_64.exe'
        with zipfile.ZipFile(templates) as z:template.write_bytes(z.read('templates/windows_release_x86_64.exe'))
        preset='''[preset.0]
name="Windows Desktop"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter="assets/characters/*.vrm,assets/characters/*.json,assets/*.json,assets/*LICENSE*.txt,assets/*COPYRIGHT*.txt,assets/CREDITS.txt,assets/fonts/*OFL.txt,assets/wordbooks/*.json,assets/wordbooks/*.txt,assets/wordbooks/licenses/*"
exclude_filter="art-source/*,tools/*,tests/*,*.blend,assets/wordbooks/sources/*,assets/wordbooks/content-review.json,assets/wordbooks/audio-audit.json,assets/fonts/NotoSansSC.ttf,assets/fonts/NotoSans.ttf"
[preset.0.options]
custom_template/release="TEMPLATE"
binary_format/architecture="x86_64"
binary_format/embed_pck=true
debug/export_console_wrapper=0
codesign/enable=false
application/modify_resources=false
'''.replace('TEMPLATE',template.as_posix())
        (project/'export_presets.cfg').write_text(preset,encoding='utf-8')
        manifest={str(f.relative_to(project)).replace('\\','/'):hashlib.sha256(f.read_bytes()).hexdigest()
                  for f in project.rglob('*') if f.is_file() and f.name!='export_presets.cfg' and '.godot' not in f.relative_to(project).parts}
        with (output/'desktop-build.log').open('w',encoding='utf-8') as log:
            for command in [[str(engine),'--headless','--editor','--path',str(project),'--import'],
                            [str(engine),'--headless','--path',str(project),'--export-release','Windows Desktop',str(output/'ARWORD.exe')]]:
                subprocess.run(command,stdout=log,stderr=log,check=True)
        (output/'desktop-source-sha256.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False),encoding='utf-8')
    exe=output/'ARWORD.exe';digest=hashlib.sha256(exe.read_bytes()).hexdigest()
    (output/'desktop-SHA256SUMS.txt').write_text(digest+'  ARWORD.exe\n',encoding='utf-8')
    print(json.dumps({'exe':str(exe),'bytes':exe.stat().st_size,'sha256':digest},ensure_ascii=False))

if __name__=='__main__':main()
