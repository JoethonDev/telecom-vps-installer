[Unit]
Description=Telecom VPS Manager
After=network.target ssh.service sshd-httpcustom.service xray.service stunnel4.service

[Service]
User=telecom-web
Group=telecom-web
EnvironmentFile=/etc/telecom-manager/telecom-manager.env
WorkingDirectory=${WORKING_DIR}
UMask=0077
PrivateTmp=true
NoNewPrivileges=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
LockPersonality=true
RestrictRealtime=true
ExecStart=${VENV_DIR}/bin/python3 -m gunicorn -w 1 -b 127.0.0.1:${PANEL_PORT} telecom_manager.app:app
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
