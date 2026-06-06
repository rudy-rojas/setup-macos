# 07 · Claude Code

Instala Claude Code con el **instalador nativo oficial**.

- `curl -fsSL https://claude.ai/install.sh | bash` → binario en `~/.local/bin/claude` (auto-actualizable).
- Asegura `~/.local/bin` en el PATH; corre `claude --version` y `claude doctor`.

## Uso
```bash
./setup.sh 07
```

## Notas
- Requiere una cuenta de **pago** (Pro/Max/Team/Enterprise/Console) o un proveedor API (Bedrock/Vertex/Foundry); el plan gratis de Claude.ai **no** da acceso.
- **No** mezclar con la versión npm (`@anthropic-ai/claude-code`) ni con el cask de Homebrew: pueden ensombrecer el binario nativo en el PATH. `claude doctor` lo detecta.
- La primera vez, ejecuta `claude` en un proyecto para abrir el login en el navegador.
