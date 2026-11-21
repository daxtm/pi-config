"""Upgrade only files matching the original kit templates."""
from pathlib import Path
import hashlib
import sys

templates = Path(__file__).resolve().parents[1] / "templates/project"
original = {'.github/workflows/ci.yml': '4a19c6e5e8685df5def77850693cf94d31091c49cd63450b4ad012154c989a77', '.github/pull_request_template.md': 'f2f80ab65954bac54fcad07660b5bbcd7490f55526b4e47ea8ce2f70f7d5a409', 'scripts/check.sh': '7911242673dd20637c19cc1b50913f73c285df83307dc2f6aee0984d3b0d6c15', 'AGENTS.md': '51a2b07b94ea1e67f69806f8c7c4f0ab29c59d82f1072bbc357c7c018c526f7f'}
for name, digest in original.items():
    path = Path(name)
    if path.is_symlink() or not path.is_file():
        continue
    content = path.read_bytes()
    if name == "AGENTS.md":
        content = content.replace(("# " + sys.argv[1] + "\n").encode(), b"# {{PROJECT_NAME}}\n", 1)
    if hashlib.sha256(content).hexdigest() != digest:
        continue
    source = templates / name
    if source.exists():
        path.write_bytes(source.read_bytes().replace(b"{{PROJECT_NAME}}", sys.argv[1].encode()))
    else:
        path.unlink()
    print("Migrated", name)
