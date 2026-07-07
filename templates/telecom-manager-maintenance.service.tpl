[Unit]
Description=Telecom Manager Maintenance
After=network.target

[Service]
Type=oneshot
User=telecom-web
Group=telecom-web
EnvironmentFile=/etc/telecom-manager/telecom-manager.env
UMask=0077
PrivateTmp=true
NoNewPrivileges=true
ExecStart=${VENV_DIR}/bin/python3 ${WORKING_DIR}/telecom_manager/scripts/maintenance.py

[Install]
WantedBy=multi-user.target
