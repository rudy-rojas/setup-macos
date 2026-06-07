# 04 · Node (fnm + pnpm)

Manages Node with **fnm** (fast, the uv philosophy for Node) and installs **pnpm**.

- `brew install fnm` + hook `eval "$(fnm env --use-on-cd --shell zsh)"` in `~/.zshrc` (exactly once).
- Installs the LTS (`fnm install --lts`), **activates** it (`fnm use --lts`) and pins it as the default.
- **pnpm arch-aware**:
  - **Apple Silicon** → standalone script (`get.pnpm.io/install.sh`), independent of Node (survives version changes with fnm).
  - **Intel (darwin-x64)** → `brew install pnpm` (the standalone script does **not** support darwin-x64).

## Usage
```bash
./setup.sh 04
```

## Notes
- `corepack` is **not** used: the Node TSC voted to remove it from the core in **25+** (in Node 24 it is still present but pnpm already treats it as a last resort).
- Do **not** use `fnm default lts-latest`: that alias does not exist until an explicit default is pinned and it fails with *"Can't find requested version"* (fnm#1203). That is why `fnm default "$(fnm current)"` is used.
- `fnm install --lts` does **not** activate the LTS in the current shell → that is why `fnm use --lts` is needed.
- On Apple Silicon, after the standalone script open a new terminal to get `PNPM_HOME` on the PATH.
- pnpm 10+/11 auto-switches to the version pinned in `packageManager` of each `package.json` (replaces corepack's role).
