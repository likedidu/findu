#!/usr/bin/env bash

set -e
exec 2>&1

# 设置各变量
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
WSPATH=${WSPATH:-'argo'}

# install sing-box
DIR_TMP="$(mktemp -d)"
EXEC=$(echo $RANDOM | md5sum | head -c 4)
wget -O - 'https://github.com/SagerNet/sing-box/releases/download/v1.6.0-alpha.1/sing-box-1.6.0-alpha.1-linux-amd64.tar.gz' | tar xz -C ${DIR_TMP}
install -m 755 ${DIR_TMP}/sing-box*/sing-box /usr/bin/app${EXEC}
rm -rf ${DIR_TMP}

generate_config() {
  cat > config.json << EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "route": {
    "rules": [
      {
        "geosite": ["openai"],
        "outbound": "warp-IPv4-out"
      }
    ]
  },
  "inbounds": [
    {
      "sniff": true,
      "sniff_override_destination": true,
      "type": "vmess",
      "tag": "vmess-in",
      "listen": "::",
      "listen_port": 63003,
      "users": [
        {
          "uuid": "${UUID}",
          "alterId": 0
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/${WSPATH}/vm",
        "max_early_data": 2048,
        "early_data_header_name": "Sec-WebSocket-Protocol"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "direct",
      "tag": "warp-IPv4-out",
      "detour": "wireguard-out",
      "domain_strategy": "ipv4_only"
    },
    {
      "type": "direct",
      "tag": "warp-IPv6-out",
      "detour": "wireguard-out",
      "domain_strategy": "ipv6_only"
    },
    {
      "type": "wireguard",
      "tag": "wireguard-out",
      "server": "162.159.192.1",
      "server_port": 2408,
      "local_address": [
        "198.18.0.1/32",
        "fd00::1/128"
      ],
      "private_key": "mBLyQdleKfbd+DyY5qfAH+35khgKVQSL6V9agcxVIWI=",
      "peer_public_key": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
      "reserved": [217, 40, 145],
      "mtu": 1280
    }
  ]
}
EOF
}

generate_pm2_file() {
  cat > /tmp/ecosystem.config.js << EOF
module.exports = {
  apps: [
    {
      name: "web",
      script: "/usr/bin/app* run -c /app/config.json"
    }
  ]
}
EOF
}


generate_config
generate_pm2_file

[ -e /tmp/ecosystem.config.js ] && pm2 start /tmp/ecosystem.config.js