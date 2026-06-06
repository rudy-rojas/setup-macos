# 09 · Redis

Instala Redis y lo arranca como servicio (lo usan las colas **Bull** de tnb-backend).

- `brew install redis` — la **fórmula** (no el cask `redis-stack`, que no se gestiona con `brew services`).
- `brew services start redis`; verifica con `redis-cli ping → PONG`.

## Uso
```bash
./setup.sh 09
```

## Notas
- `brew services start` (sin sudo) registra un LaunchAgent por usuario (arranca al iniciar sesión). No lo mezcles con `sudo brew services` (LaunchDaemon de sistema) para evitar servicios duplicados.
