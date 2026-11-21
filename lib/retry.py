"""Remember one explicit workflow retry until its repair has been merged and installed."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

store = Path.home() / ".local/share/pi-kit/retries"
deploy = Path.home() / ".local/share/pi-config"
commands = {"pi-ship":"bin/pi-ship", "pi-test-branch":"bin/pi-test-branch", "pinew":"new-project.sh", "pi-branch":"bin/pi-branch"}
def git(cwd, *args):
    return subprocess.check_output(["git","-C",cwd,*args], text=True).strip()
def identity(cwd):
    return [git(cwd,"rev-parse","HEAD"),git(cwd,"branch","--show-current"),git(cwd,"status","--porcelain")]
if sys.argv[1] == "save":
    repair, cmd, *args = sys.argv[2:]
    if cmd not in commands:
        sys.exit("Unsupported retry command")
    cwd = os.getcwd()
    record = [repair,cwd,identity(cwd),cmd,args]
    store.mkdir(parents=True,exist_ok=True)
    path = store / (hashlib.sha256(json.dumps(record).encode()).hexdigest()+".json")
    if not path.with_suffix(".used").exists():
        temp=path.with_suffix(".tmp")
        temp.write_text(json.dumps(record)); temp.replace(path)
else:
    for path in sorted(store.glob("*.json")):
        repair,cwd,original,cmd,args = json.loads(path.read_text())
        if subprocess.run(["git","-C",deploy,"merge-base","--is-ancestor",repair,"HEAD"],stderr=subprocess.DEVNULL).returncode:
            continue
        if not Path(cwd).is_dir() or identity(cwd)!=original:
            print("Original checkout changed; review pending retry in",path); continue
        path.replace(path.with_suffix(".used"))
        result=subprocess.run([deploy/commands[cmd],*args],cwd=cwd)
        print("Retried",cmd,"in",cwd,"exit",result.returncode)
