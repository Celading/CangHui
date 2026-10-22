#!/usr/bin/env python3
"""Run an owned native sampler and freeze exact executable, sources and observations."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
app = root / 'examples/motion-lab'
binary = app / 'target/release/bin/main'
if not binary.is_file():
    parser.error('build examples/motion-lab first')
output = args.output.absolute()
output.mkdir()  # Exclusive creation; never replace prior evidence.
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
names = sorted({str(p.relative_to(root)) for prefix in ['src','sdl/src','examples/motion-lab/src','packages/kit/src'] for p in (root/prefix).rglob('*.cj') if 'target' not in p.relative_to(root).parts and not p.is_symlink()})
source_hashes = {name: digest(root / name) for name in names
                 if name.startswith(('src/', 'sdl/src/', 'examples/motion-lab/src/', 'packages/kit/src/'))}
env = dict(os.environ)
env['DYLD_LIBRARY_PATH'] = str(root / 'sdl/.sdl3')
env['CANGHUI_HARMONYOS_SANS'] = str(root / 'assets/fonts/HarmonyOS_Sans_SC.ttf')
command = [str(binary), '--export-native-design', str(output)]
result = subprocess.run(command, cwd=app, env=env, capture_output=True, text=True, timeout=300)
(output / 'capture.log').write_text(result.stdout + result.stderr)
if result.returncode:
    raise SystemExit(f'native sampler failed: {result.returncode}')
snapshots = sorted(output.glob('family-*.json'))
if len(snapshots) != 160:
    raise SystemExit(f'incomplete observation inventory: {len(snapshots)}')
receipt = {'schema': 'canghui.native-motion-capture/v1',
           'executableSha256': digest(binary),
           'sourceRevision': subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip(),
           'sourceFiles': source_hashes,
           'fontSha256': digest(root / 'assets/fonts/HarmonyOS_Sans_SC.ttf'),
           'snapshotSha256': {p.name: digest(p) for p in snapshots},
           'nativeHost': os.uname().sysname, 'sourceRendering': 'executed with owned native renderer',
           'businessActionsExecuted': False,
           'otherHostAcceptance': False}
(output / 'capture-proof.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps({'snapshots': len(snapshots), 'executableSha256': receipt['executableSha256']}))
