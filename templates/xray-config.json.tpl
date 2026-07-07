{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log"
  },
  "inbounds": [
    {
      "tag": "vmess-tcp-tls",
      "port": ${VMESS_PORT},
      "listen": "${LISTEN_ADDR}",
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tcpSettings": {
          "header": {
            "type": "none"
          }
        },
        "tlsSettings": {
          "serverName": "${TLS_SERVER_NAME}",
          "certificates": [
            {
              "certificateFile": "/usr/local/etc/xray/certs/server.crt",
              "keyFile": "/usr/local/etc/xray/certs/server.key"
            }
          ]
        }
      }
    },
    {
      "tag": "vless-tcp-tls-vision",
      "port": ${VLESS_PORT},
      "listen": "${LISTEN_ADDR}",
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tcpSettings": {
          "header": {
            "type": "none"
          }
        },
        "tlsSettings": {
          "serverName": "${TLS_SERVER_NAME}",
          "certificates": [
            {
              "certificateFile": "/usr/local/etc/xray/certs/server.crt",
              "keyFile": "/usr/local/etc/xray/certs/server.key"
            }
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
