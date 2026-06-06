# 04 · Node (fnm + pnpm)

Gestiona Node con **fnm** (rápido, la filosofía de uv para Node) e instala **pnpm**.

- `brew install fnm` + hook `eval "$(fnm env --use-on-cd --shell zsh)"` en `~/.zshrc` (una sola vez).
- Instala el LTS (`fnm install --lts`), lo **activa** (`fnm use --lts`) y lo fija como default.
- **pnpm arch-aware**:
  - **Apple Silicon** → script standalone (`get.pnpm.io/install.sh`), independiente de Node (sobrevive a cambios de versión con fnm).
  - **Intel (darwin-x64)** → `brew install pnpm` (el script standalone **no** soporta darwin-x64).

## Uso
```bash
./setup.sh 04
```

## Notas
- **No** se usa `corepack`: el TSC de Node votó retirarlo del core en la **25+** (en Node 24 sigue presente pero pnpm ya lo trata como último recurso).
- **No** usar `fnm default lts-latest`: ese alias no existe hasta fijar un default explícito y falla con *"Can't find requested version"* (fnm#1203). Por eso se usa `fnm default "$(fnm current)"`.
- `fnm install --lts` **no** activa el LTS en la shell actual → por eso el `fnm use --lts`.
- En Apple Silicon, tras el script standalone abre una terminal nueva para tener `PNPM_HOME` en el PATH.
- pnpm 10+/11 auto-cambia a la versión fijada en `packageManager` de cada `package.json` (reemplaza el rol de corepack).
