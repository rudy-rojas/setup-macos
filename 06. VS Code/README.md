# 06 · VS Code

Instala VS Code, las extensiones del stack TNB (idempotente) y aplica ajustes **sin pisar** los tuyos.

- Cask con `--adopt` (adopta una copia ya arrastrada a `/Applications` en lugar de fallar).
- Extensiones: `claude-code`, `eslint`, `prettier`, `tailwindcss`, `expo-tools` (guard con `grep -qix`).
- `settings.json`: merge profundo con `jq` (`.[0] * .[1]`) → tus claves se preservan; solo gestionamos *format on save*, Prettier por defecto y ESLint `fixAll: explicit`.

## Uso
```bash
./setup.sh 06
```

## Notas
- Si tu `settings.json` tiene `//` comentarios o comas finales (JSONc), `jq` no lo parsea: el módulo **no lo toca** y avisa.
- `source.fixAll.eslint` usa el string `"explicit"` (el booleano está deprecado desde VS Code ~1.85).
- La lista completa de tus **52** extensiones está en `00. Inventory/vscode-extensions.txt`:
  ```bash
  while read -r e; do code --install-extension "${e%@*}"; done < "00. Inventory/vscode-extensions.txt"
  ```
