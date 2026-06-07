# 05 · Git & GitHub

Instala git + GitHub CLI, aplica la config global de TNB y autentica `gh` solo si falta.

- `brew install git gh jq`.
- `git config --global`: identidad, `init.defaultBranch main`, `pull.rebase false`, `core.editor "code --wait"`.
- `gh`: login web **solo si** `gh auth status` falla (nunca re-pregunta a un usuario ya autenticado). En una corrida orquestada (`./setup.sh`) este login se **difiere al final**, tras instalar todo, para no interrumpir el proceso; en solitario (`./setup.sh 05`) se hace en el momento.

## Uso
```bash
./setup.sh 05
# identidad personalizada:
GIT_USER_NAME="Tu Nombre" GIT_USER_EMAIL="tu@correo.com" ./setup.sh 05
```

## Notas
- Identidad por defecto: `TheNationalBuilders <tnb@thenationalbuilders.com>` (override con las env vars).
- `gh auth login --web` abre el navegador (paso interactivo).
- `gh auth status` se acota a `--hostname github.com` para que un host enterprise con token caducado no dispare un re-login.
