# 03 · Python (uv)

Manages Python with **uv** and sets **Python 3.12** as the default `python3`.

- Installs uv with the official installer (`astral.sh/uv/install.sh`) — no prior Python needed.
- `uv python install 3.12 --default` creates the `python` / `python3` / `python3.12` shims in `~/.local/bin`.
- `uv python update-shell` ensures `~/.local/bin` on the PATH of future shells.

## Usage
```bash
./setup.sh 03
```

## Notes
- `--default` is marked as **experimental** by uv; the versioned executable `python3.12` is the guaranteed stable one.
- `~/.local/bin` is the same path on Apple Silicon and Intel → this module is architecture-independent.
- Do **not** use macOS's `/usr/bin/python3` (it is a stub that triggers the CLT installation).
- To pin the exact patch and for reproducibility: `uv python install 3.12.x --default`.
- Mind the PATH precedence: if a brew Python appears before `~/.local/bin`, it would win. Check with `command -v python3`.
