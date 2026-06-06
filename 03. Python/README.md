# 03 · Python (uv)

Gestiona Python con **uv** y deja **Python 3.12** como `python3` por defecto.

- Instala uv con el instalador oficial (`astral.sh/uv/install.sh`) — no necesita Python previo.
- `uv python install 3.12 --default` crea los shims `python` / `python3` / `python3.12` en `~/.local/bin`.
- `uv python update-shell` garantiza `~/.local/bin` en el PATH de shells futuros.

## Uso
```bash
./setup.sh 03
```

## Notas
- `--default` está marcado como **experimental** por uv; el ejecutable versionado `python3.12` es el estable garantizado.
- `~/.local/bin` es la misma ruta en Apple Silicon e Intel → este módulo es independiente de la arquitectura.
- **No** usar `/usr/bin/python3` de macOS (es un stub que dispara la instalación de los CLT).
- Para fijar el patch exacto y reproducibilidad: `uv python install 3.12.x --default`.
- Cuidado con la precedencia del PATH: si un Python de brew aparece antes que `~/.local/bin`, ganaría. Verifica con `command -v python3`.
