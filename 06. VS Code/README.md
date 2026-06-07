# 06 · VS Code

Installs VS Code, the TNB stack extensions (idempotent) and applies settings **without clobbering** yours.

- Cask with `--adopt` (adopts a copy already dragged into `/Applications` instead of failing).
- Extensions: `claude-code`, `eslint`, `prettier`, `tailwindcss`, `expo-tools` (guarded with `grep -qix`).
- `settings.json`: deep merge with `jq` (`.[0] * .[1]`) → your keys are preserved; we only manage *format on save*, Prettier as the default and ESLint `fixAll: explicit`.

## Usage
```bash
./setup.sh 06
```

## Notes
- If your `settings.json` has `//` comments or trailing commas (JSONc), `jq` cannot parse it: the module **leaves it untouched** and warns.
- `source.fixAll.eslint` uses the string `"explicit"` (the boolean has been deprecated since VS Code ~1.85).
- The complete list of your **52** extensions is in `00. Inventory/vscode-extensions.txt`:
  ```bash
  while read -r e; do code --install-extension "${e%@*}"; done < "00. Inventory/vscode-extensions.txt"
  ```
