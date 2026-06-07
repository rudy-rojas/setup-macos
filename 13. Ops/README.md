# 13 · Ops / VPS

Utilities for operating the VPS.

- `sshpass` — with fallback to the `hudochenkov/sshpass` tap if not in homebrew-core.

## Usage
```bash
./setup.sh 13
```

## Notes
- `sshpass` lets you pass the SSH password non-interactively; use it only in controlled environments (it is less secure than SSH keys).
