# 09 · Redis

Installs Redis and starts it as a service (used by tnb-backend's **Bull** queues).

- `brew install redis` — the **formula** (not the `redis-stack` cask, which is not managed by `brew services`).
- `brew services start redis`; verify with `redis-cli ping → PONG`.

## Usage
```bash
./setup.sh 09
```

## Notes
- `brew services start` (without sudo) registers a per-user LaunchAgent (starts at login). Do not mix it with `sudo brew services` (system LaunchDaemon) to avoid duplicate services.
