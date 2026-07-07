[Unit]
Description=Telecom Manager Maintenance Timer
After=network.target

[Timer]
OnBootSec=1min
OnUnitActiveSec=10min
AccuracySec=30s
Unit=telecom-manager-maintenance.service

[Install]
WantedBy=timers.target
