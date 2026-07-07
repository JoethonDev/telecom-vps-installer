[Unit]
Description=Telecom Manager Maintenance Timer
After=network.target

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Unit=telecom-manager-maintenance.service

[Install]
WantedBy=timers.target
