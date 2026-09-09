# GitHub self-hosted runner hosts

Docker Compose + systemd watchdog configs for the n3otech GitHub Actions
self-hosted runner hosts. Each host runs two runner containers
(`ghcr.io/actions/actions-runner:2.335.1`) paired with two Docker-in-Docker
containers (`docker:27.5.1-dind`, TLS on port 2376).

| Host | Compose dir | Compose service | Subnet | Runner names |
|---|---|---|---|---|
| `n3o0x65lnxdsk0001` | `/data/runners` | `github-runners-n3o0x65lnx.service` | 172.29.0.0/16 | `n3o0x65lnxrun001/002` |
| `twd0x5dlnxdsk0001` | `/data/runners-v2` | `dind-runner.service` | 172.28.0.0/16 | `twd0x5dlnxrun001/002` |

## Layout

```
github-runners/
├── example.env                     # .env template (tokens are placeholders)
├── n3o0x65lnxdsk0001/
│   └── docker-compose.yml          # as deployed on n3o0x65lnxdsk0001
├── twd0x5dlnxdsk0001/
│   └── docker-compose.yml          # as deployed on twd0x5dlnxdsk0001
└── watchdog/
    ├── runner-watchdog.sh          # -> /usr/local/bin/runner-watchdog.sh
    ├── runner-watchdog.service     # -> /etc/systemd/system/ (substitute __COMPOSE_DIR__)
    └── runner-watchdog.timer       # -> /etc/systemd/system/
```

## Secrets

- **Never commit `.env`** (guarded by `.gitignore`). It holds
  `RUNNER_TOKEN_001` / `RUNNER_TOKEN_002` and lives only on the hosts
  (`chmod 600`).
- Registration tokens are single-use and expire ~1 hour after generation.
  The compose startup is idempotent (`cp -n` of persisted credentials), so
  tokens are only needed for the *first* registration of a runner; restarts
  reuse the saved credentials from the bind-mounted `config/` dir.
- The watchdog authenticates via the host's `gh` CLI (needs `admin:org` on
  the org) — no tokens in the script.

## Deploying to a new host

1. Copy the host's compose dir (e.g. `/data/runners`) and place
   `docker-compose.yml` in it. Adjust per-host values:
   - `hostname` / `RUNNER_NAME` / `--name` (runner names must be unique org-wide)
   - `ipam` subnet (must not collide with other docker networks on the host)
2. `cp example.env .env && chmod 600 .env`, then generate fresh tokens:
   ```bash
   gh api orgs/n3otech/actions/runners/registration-token --method POST --jq '.token'
   ```
   (one per runner; use within the hour)
3. `docker compose up -d` — first start registers the runners, subsequent
   starts reuse persisted credentials.

## Installing the watchdog

The watchdog runs every 5 minutes and restarts any runner container that is
either (1) `health=unhealthy` per Docker, or (2) reported not-online by the
GitHub API (`gh api orgs/n3otech/actions/runners`). It was added after a
runner hung for 6 days while still reporting "healthy" — the old healthcheck
only checked the `.runner` file and the DinD port, not GitHub connectivity.

The runner healthcheck in the compose files requires an **established :443
connection** (the broker long-poll) in addition to the `.runner` file and
DinD port, so a hung listener flips to `unhealthy` within ~2 minutes.

```bash
# 1. Install the script
sudo install -m 755 watchdog/runner-watchdog.sh /usr/local/bin/runner-watchdog.sh

# 2. Install the units, substituting the compose dir for __COMPOSE_DIR__
sed "s|__COMPOSE_DIR__|/data/runners|" watchdog/runner-watchdog.service \
  | sudo tee /etc/systemd/system/runner-watchdog.service
sudo install -m 644 watchdog/runner-watchdog.timer /etc/systemd/system/runner-watchdog.timer

# 3. Enable
sudo systemctl daemon-reload
sudo systemctl enable --now runner-watchdog.timer

# 4. Verify
sudo systemctl start runner-watchdog.service   # should finish with exit 0
journalctl -u runner-watchdog.service --no-pager | tail
```

Notes:
- The service sets `HOME=/home/bsamba` because `gh` needs it for auth.
- Files edited/created on Windows have CRLF line endings — run
  `sed -i "s/\r$//"` on the script before installing, or it fails with
  `env: 'bash\r': No such file or directory`.
- Restarts are safe: registration is idempotent (see Secrets above).

## Per-host differences (as of 2026-09-08)

- n3o mounts `./config/run00X` read-write; twd mounts it `:ro` (fine in
  steady state — the write path only runs during first registration).
- twd's compose file carries a large header comment block and an unused
  `x-runner-command` YAML anchor (kept for reference).
- Both hosts keep `docker-compose.yml.bak-<date>` backups alongside the
  live file; older `*.backup-*` files are host-local history.
