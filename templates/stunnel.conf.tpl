pid = /run/stunnel4/stunnel.pid
foreground = no
debug = 5
output = /var/log/stunnel4/stunnel.log

[ssh_tls]
accept = ${ACCEPT_ADDR}:${STUNNEL_PORT}
connect = 127.0.0.1:${SSH_COMPAT_PORT}
cert = /etc/stunnel/stunnel.pem
TIMEOUTclose = 0
