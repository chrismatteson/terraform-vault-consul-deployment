#!/bin/bash 

set -e

function has_yum {
  [ -n "$(command -v yum)" ]
}

function has_apt_get {
  [ -n "$(command -v apt-get)" ]
}

log_info "Installing dependencies"

if $(has_apt_get); then
  sudo apt-get update -y
  sudo apt-get install -y awscli curl unzip jq
elif $(has_yum); then
  sudo yum update -y
  sudo yum install -y aws curl unzip jq
else
  log_error "Could not find apt-get or yum. Cannot install dependencies on this OS."
  exit 1
fi

local path=%{ if var.path != "" }${var.path}%{else}"/opt/consul"%{endif}
local ca-path=%{ if var.ca-path != "" }${var.ca-path}%{else}"$path/tls/ca"%{endif}
local cert-file-path=%{ if var.cert-file-path != "" }${var.cert-file-path}%{else}"$path/tls/"%{endif}
local key-file-path=%{ if var.key-file-path != "" }${var.key-file-path}%{else}"$path/tls/"%{endif}

curl -O https://raw.githubusercontent.com/hashicorp/terraform-aws-consul/master/modules/install-consul/install-consul -O https://raw.githubusercontent.com/hashicorp/terraform-aws-consul/master/modules/run-consul/run-consul

chmod +x ./install-consul
chmod +x ./run-consul
/bin/bash ./install-consul %{ if version != "" }--version ${version} %{ endif}%{ if download-url != "" }--download-url ${download-url} %{ endif}%{ if path != "" }--path ${path} %{ endif}%{ if user != "" }--user ${user} %{ endif} ${download-url} %{ endif}
cp ./run-consul ${var.path}/bin/run-consul
%{ if enable_rpc_encryption }
aws s3 cp s3://${var.bucket}/ca.pem $ca-path/ca.pem
aws s3 cp s3://${var.bucket}/ca_private_key.pem $ca-path/ca_private_key.pem
$path/bin/consul tls cert create -server %{ if var.datacenter != "" }-dc=${var.datacenter} %{ endif }
%{ endif }
/bin/bash $path/bin/run-consul %{ if server == true }--server %{ endif}%{ if client == true }--client %{ endif}%{ if config-dir != "" }--config-dir ${config-dir} %{ endif}%{ if data-dir != "" }--data-dir ${data-dir} %{ endif}%{ if systemd-stdout != "" }--systemd-stdout ${systemd-stdout} %{ endif}%{ if systemd-stderr != "" }--systemd-stderr ${systemd-stderr} %{ endif}%{ if bin-dir != "" }--bin-dir ${bin-dir} %{ endif}%{ if user != "" }--user ${user} %{ endif}%{ if cluster-tag-key != "" }--cluster-tag-key ${cluster-tag-key} %{ endif}%{ if cluster-tag-value != "" }--cluster-tag-value ${cluster-tag-value} %{ endif}%{ if datacenter != "" }--datacenter ${datacenter} %{ endif}%{ if autopilot-cleanup-dead-servers != "" }--autopilot-cleanup-dead-servers ${autopilot-cleanup-dead-servers} %{ endif}%{ if autopilot-last-contact-threshold != "" }--autopilot-last-contact-threshold ${autopilot-last-contact-threshold} %{ endif}%{ if autopilot-max-trailing-logs != "" }--autopilot-max-trailing-logs ${autopilot-max-trailing-logs} %{ endif}%{ if autopilot-server-stabilization-time != "" }--autopilot-server-stabilization-time ${autopilot-server-stabilization-time} %{ endif}%{ if autopilot-redundancy-zone-tag != "" }--autopilot-redundancy-zone-tag ${autopilot-redundancy-zone-tag} %{ endif}%{ if autopilot-disable-upgrade-migration != "" }--autopilot-disable-upgrade-migration ${autopilot-disable-upgrade-migration} %{ endif}%{ if autopilot-upgrade-version-tag != "" }--autopilot-upgrade-version-tag ${autopilot-upgrade-version-tag} %{ endif}%{ if enable-gossip-encryption != "" }--enable-gossip-encryption ${enable-gossip-encryption} %{ endif}%{ if gossip-encryption-key != "" }--gossip-encryption-key ${gossip-encryption-key} %{ endif}%{ if enable-rpc-encryption }--enable-rpc-encryption --ca-path $ca-path --cert-file-path $cert-file-path --key-file-path $key-file-path %{ endif}%{ if environment != "" }--environment ${environment} %{ endif}%{ if skip-consul-config != "" }--skip-consul-config ${skip-consul-config} %{ endif}%{ if recursor != "" }--recursor ${recursor} %{ endif}

while [ curl http://127.0.0.1:8500/v1/status/leader -eq "" ] do
  echo "Waiting for Consul Cluster to start"
  sleep 3
done
$path/bin/consul license put
