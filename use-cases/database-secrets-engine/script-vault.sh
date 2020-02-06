#!/bin/bash

# Ensure MYSQL_USER, MYSQL_PASSWORD, and MYSQL_HOST are set before running this script.

cat << EOF > /tmp/getmysqlcreds.hcl
path "mysql/creds/readonly" {
  capabilities = ["read"]
}
EOF

vault secrets enable mysql
vault write mysql/config/connection connection_url="$MYSQL_USER:$MYSQL_PASSWORD@tcp($MYSQL_HOST:3306)/"
vault write mysql/roles/readonly sql="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT SELECT ON *.* TO '{{name}}'@'%';"
vault policy write getmysqlcreds /tmp/getmysqlcreds.hcl
