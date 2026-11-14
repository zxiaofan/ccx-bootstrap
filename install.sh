#!/usr/bin/env bash
set -euo pipefail
[[ "$(uname -s)" == Linux && "$(id -u)" != 0 ]] || { echo 'Use a non-root Linux user.' >&2; exit 1; }
[[ -r /dev/tty && -w /dev/tty ]] || { echo 'An interactive terminal is required.' >&2; exit 1; }
command -v python3 >/dev/null || { echo 'Install python3, then retry.' >&2; exit 1; }
command -v gh >/dev/null || { echo 'Install GitHub CLI (gh), then retry.' >&2; exit 1; }
if ! gh auth status >/dev/null 2>&1; then gh auth login --hostname github.com --git-protocol https --web < /dev/tty; fi
setup="$(python3 - <<'PYCODE'
import hashlib,json,os,re,subprocess,sys,tempfile
from pathlib import Path
def run(*a):
 return subprocess.check_output(['gh',*a],env=dict(os.environ,GH_PROMPT_DISABLED='1'),timeout=300)
r=json.loads(run('api','--method','GET','repos/zxiaofan/ccx/releases/latest'))
t=r.get('tag_name','')
if r.get('draft') or r.get('prerelease') or not re.fullmatch(r'v\d{4}\.\d{2}\.\d{2}\.[1-9]\d*',t) or r.get('html_url')!='https://github.com/zxiaofan/ccx/releases/tag/'+t: raise SystemExit('Invalid official release')
root=Path(os.environ.get('XDG_CACHE_HOME',str(Path.home()/'.cache')))/'ccx/bootstrap'/t
root.mkdir(parents=True,exist_ok=True,mode=0o700)
for name in ('release-download.py','install.sh','setup-linux.sh'):
 a=[a for a in r['assets'] if a['name']==name]
 if len(a)!=1 or a[0].get('state')!='uploaded' or not 0<a[0].get('size',0)<=1048576 or not re.fullmatch(r'sha256:[a-f0-9]{64}',a[0].get('digest','')): raise SystemExit('Missing trusted setup asset')
 a=a[0];p=root/name
 if not p.exists():
  print('Downloading '+name,file=sys.stderr)
  with tempfile.TemporaryDirectory(prefix='ccx-bootstrap-') as stage:
   run('release','download',t,'--repo','zxiaofan/ccx','--pattern',name,'--dir',stage)
   data=(Path(stage)/name).read_bytes()
   if len(data)!=a['size'] or 'sha256:'+hashlib.sha256(data).hexdigest()!=a['digest']: raise SystemExit('Asset hash mismatch; not executed')
   p.write_bytes(data);p.chmod(0o700)
 data=p.read_bytes()
 if len(data)!=a['size'] or 'sha256:'+hashlib.sha256(data).hexdigest()!=a['digest']: raise SystemExit('Cached asset hash mismatch; not executed')
print(root/'setup-linux.sh')
PYCODE
)"
exec bash "$setup" < /dev/tty
