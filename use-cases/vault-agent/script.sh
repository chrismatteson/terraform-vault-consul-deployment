#!/bin/bash

# Ensure MYSQL_HOST and VAULT_ADDR are set before running this script. Run this script as root with an inherited environment using sudo -E.

wget https://releases.hashicorp.com/vault/1.3.2/vault_1.3.2_linux_amd64.zip -O /tmp/vault.zip
apt-get install -y unzip
unzip -o /tmp/vault.zip -d /tmp/vault
cp /tmp/vault/vault /usr/local/bin/vault
chmod +x /usr/local/bin/vault


cat << EOF > /opt/flask/mysqlcreds.json.ctmpl
{{ with secret "mysql/creds/readonly" }}
{
  "username": "{{ .Data.username }}",
  "password": "{{ .Data.password }}",
  "hostname": "$MYSQL_HOST"
}
{{ end }}
EOF

mkdir -p /opt/vault
cat << EOF > /opt/vault/default.hcl
pid_file = "./pidfile"

vault {
        address = "$VAULT_ADDR"
}

auto_auth {
        method "aws" {
                mount_path = "auth/aws"
                config = {
                        type = "ec2"
                        role = "app-role"
                }
        }
}

cache {
        use_auto_auth_token = true
}

listener "tcp" {
         address = "127.0.0.1:8100"
         tls_disable = true
}

template {
  source      = "/opt/flask/mysqlcreds.json.ctmpl"
  destination = "/opt/flask/mysqlcreds.json"
}
EOF

cat << EOF > /etc/systemd/system/vault-agent.service
[Unit]
Description=Vault Agent

[Service]
Restart=always
EnvironmentFile=
PermissionsStartOnly=true
ExecStartPre=/sbin/setcap 'cap_ipc_lock=+ep' /usr/local/bin/vault
ExecStart=/usr/local/bin/vault agent -config /opt/vault/default.hcl
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vault-agent.service
systemctl restart vault-agent.service
