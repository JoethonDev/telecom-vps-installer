[Unit]
Description=Telecom Manager localhost SSH compatibility listener
After=network.target ssh.service

[Service]
ExecStartPre=/usr/bin/mkdir -p /run/sshd
ExecStart=/usr/sbin/sshd -D -f /etc/ssh/sshd_config_httpcustom
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
