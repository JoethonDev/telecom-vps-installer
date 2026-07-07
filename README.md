# telecom-vps-installer

Installs and manages a Telecom VPS with SSH SSL/stunnel, Xray VMess TCP TLS, Xray VLESS TCP TLS Vision, and the Telecom Manager web panel.

## Usage

```bash
curl -fsSL https://github.com/telecom-vps/telecom-vps-installer/releases/latest/download/bootstrap-install.sh | bash
```

## Modes

- `install` — Full installation
- `upgrade-app` — Upgrade web panel only
- `upgrade-infra` — Upgrade packages and Xray
- `repair-permissions` — Fix file ownership and modes
- `diagnose` — Non-destructive system report
- `backup` — Database backup
- `restore` — Database restore
- `uninstall` — Remove managed resources
