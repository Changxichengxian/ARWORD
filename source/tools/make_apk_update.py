"""Produce GitHub release assets and compact byte-exact patches from installed APKs."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct
import os
import subprocess
import zipfile


def digest(data):
    return hashlib.sha256(data).hexdigest()


def verify_godot_assets(archive):
    """Godot reads external APK assets using sizes from its own sparse pack."""
    directory = archive.read("assets/assets.sparsepck")
    if directory[:8] != b"GDPC\x03\0\0\0" or struct.unpack_from("<I", directory, 20)[0] != 6:
        raise ValueError("Expected a Godot v3 sparse resource index.")
    cursor, = struct.unpack_from("<Q", directory, 32)
    count, = struct.unpack_from("<I", directory, cursor)
    cursor += 4
    indexed = set()
    for _ in range(count):
        length, = struct.unpack_from("<I", directory, cursor)
        cursor += 4
        name = directory[cursor:cursor+length].rstrip(b"\0").decode("utf8")
        cursor += length
        offset, size, checksum, flags = struct.unpack_from("<QQ16sI", directory, cursor)
        cursor += 36
        path = "assets/" + name
        if path in indexed or offset or flags:
            raise ValueError(f"Invalid sparse resource entry: {name}")
        indexed.add(path)
        try:
            data = archive.read(path)
        except KeyError as error:
            raise ValueError(f"Missing indexed Godot resource: {name}") from error
        if len(data) != size or hashlib.md5(data).digest() != checksum:
            raise ValueError(f"APK content differs from Godot's resource index: {name}")
    scripts = {name for name in archive.namelist() if name.startswith("assets/scripts/") and not name.endswith("/")}
    if cursor != len(directory) or "assets/project.binary" not in indexed or not scripts.issubset(indexed):
        raise ValueError("Incomplete Godot resource index.")


def payloads(path, data):
    """APK ZIP local headers include alignment padding; offsets differ between builds."""
    with zipfile.ZipFile(path) as archive:
        for e in sorted(archive.infolist(), key=lambda item: item.header_offset):
            start = e.header_offset
            name_n, extra_n = struct.unpack_from('<HH', data, start + 26)
            pos = start + 30 + name_n + extra_n
            if e.compress_size >= 32:
                yield pos, e.compress_size


def make_patch(old_path, target_path, out):
    old, new = old_path.read_bytes(), target_path.read_bytes()
    known = {(n, digest(memoryview(old)[pos:pos+n])): pos for pos, n in payloads(old_path, old)}
    cursor = 0
    copied = 0
    with out.open('wb') as dest, gzip.GzipFile(fileobj=dest, mode='wb', filename='', mtime=0, compresslevel=5) as patch:
        patch.write(b'LTD1' + hashlib.sha256(old).digest() + hashlib.sha256(new).digest() + struct.pack('>Q', len(new)))
        for start, n in payloads(target_path, new):
            source = known.get((n, digest(memoryview(new)[start:start+n])))
            if source is None:
                continue
            if start != cursor:
                patch.write(struct.pack('>BQ', 0, start-cursor))
                patch.write(memoryview(new)[cursor:start])
            patch.write(struct.pack('>BQQ', 1, n, source))
            cursor = start+n
            copied += n
        if cursor < len(new):
            patch.write(struct.pack('>BQ', 0, len(new)-cursor))
            patch.write(memoryview(new)[cursor:])
        patch.write(b'\x02')
    return copied


def verify_patch(old_path, patch_path, new_path):
    """Independent streaming round-trip verification before the asset can enter a manifest."""
    h = hashlib.sha256()
    with old_path.open('rb') as old, gzip.open(patch_path, 'rb') as patch:
        assert patch.read(4) == b'LTD1'
        assert patch.read(32).hex() == digest(old_path.read_bytes())
        expected = patch.read(32).hex()
        size, = struct.unpack('>Q', patch.read(8))
        count = 0
        while (opcode := patch.read(1)) != b'\x02':
            if opcode not in (b'\x00', b'\x01'):
                raise ValueError('Invalid operation')
            length, = struct.unpack('>Q', patch.read(8))
            reader = patch
            if opcode == b'\x01':
                old.seek(struct.unpack('>Q', patch.read(8))[0])
                reader = old
            while length:
                buf = reader.read(min(length, 1024*1024))
                if not buf:
                    raise ValueError('Truncated operation')
                h.update(buf)
                length -= len(buf)
                count += len(buf)
        assert not patch.read(1) and count == size == new_path.stat().st_size
        assert h.hexdigest() == expected == digest(new_path.read_bytes())


def asset(path):
    return {'asset': path.name, 'bytes': path.stat().st_size, 'sha256': digest(path.read_bytes())}

def verify_signers(path, java, apksigner):
    result=subprocess.run([java,'-jar',apksigner,'verify','--print-certs',path],capture_output=True,encoding='utf-8',errors='replace')
    certs=re.findall(r'^Signer #\d+ certificate SHA-256 digest: ([a-fA-F0-9]{64})$',result.stdout,re.M)
    if result.returncode or not certs:
        raise ValueError(f'APK signature verification failed: {path.name}')
    return set(certs)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--apk', type=Path, required=True, help='Public signed APK only')
    p.add_argument('--base', type=Path, action='append', default=[], help='Old installed APK, used locally only')
    p.add_argument('--version', required=True)
    p.add_argument('--code', type=int, required=True)
    p.add_argument('--aapt2', type=Path, help='Android SDK aapt2, used to check target package/version')
    p.add_argument('--java', default='java', help='Java executable for Android SDK apksigner')
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    if not re.fullmatch(r'[0-9]+(?:\.[0-9]+){2}', a.version) or a.code <= 0:
        p.error('invalid version')
    if not a.aapt2:
        sdk=Path(os.environ.get('ANDROID_SDK_ROOT') or os.environ.get('ANDROID_HOME') or (Path.home()/'AppData/Local/Android/Sdk'))
        exes=sorted((sdk/'build-tools').glob('*/aapt2.exe' if os.name=='nt' else '*/aapt2'))
        if not exes:
            p.error('Specify --aapt2 for the Android SDK build tool')
        a.aapt2=exes[-1]
    info=subprocess.check_output([a.aapt2,'dump','badging',a.apk],encoding='utf-8')
    apksigner=a.aapt2.parent/'lib/apksigner.jar'
    target_certs=verify_signers(a.apk,a.java,apksigner)
    app_id='io.github.changxichengxian.arword'
    package=f"package: name='{app_id}' versionCode='{a.code}' versionName='{a.version}'"
    if package not in info:
        p.error('Manifest must match the target APK package, versionCode and versionName')
    with zipfile.ZipFile(a.apk) as archive:
        verify_godot_assets(archive)
        if any(n.lower().endswith(('.vrm', '.arvoice')) for n in archive.namelist()):
            p.error('Personal character or voice in target APK. Generate a public build with -PublicRelease.')
    for base in a.base:
        if verify_signers(base,a.java,apksigner)!=target_certs:
            p.error('Base and target APK must have the same signing certificate')
        base_info=subprocess.check_output([a.aapt2,'dump','badging',base],encoding='utf-8')
        match=re.search(r"^package: name='([^']+)' versionCode='([0-9]+)'",base_info,re.M)
        if not match or match.group(1)!=app_id or int(match.group(2))>=a.code:
            p.error('Patch base must be an earlier ARWORD app version with the same application ID')
    if a.output.exists() and any(a.output.iterdir()):
        p.error('Use an empty directory for release assets')
    a.output.mkdir(parents=True, exist_ok=True)
    target = a.output / f'ARWORD-{a.version}.apk'
    shutil.copyfile(a.apk, target)
    manifest = {'format': 1, 'package': app_id, 'code': a.code, 'version': a.version,
                'tag': 'v'+a.version, 'full': asset(target), 'patches': []}
    for base in a.base:
        old_hash = digest(base.read_bytes())
        if any(i['base_sha256'] == old_hash for i in manifest['patches']):
            continue
        path = a.output / f'from-{old_hash[:16]}-{a.version}.ltd.gz'
        copied = make_patch(base, target, path)
        verify_patch(base, path, target)
        if path.stat().st_size >= target.stat().st_size:
            path.unlink()
            continue
        manifest['patches'].append({**asset(path), 'base_sha256': old_hash})
        print(f'{base.name}: reuses {copied:,} bytes; downloads {path.stat().st_size:,} bytes')
    (a.output/'update.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2), 'utf-8')

if __name__ == '__main__':
    main()
