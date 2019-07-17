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

local path=%{ if path != "" }${path}%{else}"/opt/consul"%{endif}
local ca-path=%{ if ca-path != "" }${ca-path}%{else}"$path/tls/ca/ca.pem"%{endif}
local ca-private-key-path=$path/tls/ca/ca_private_key.pem
local cert-file-path=%{ if cert-file-path != "" }${cert-file-path}%{else}"$path/tls/"%{endif}
local key-file-path=%{ if key-file-path != "" }${key-file-path}%{else}"$path/tls/"%{endif}

curl -O https://raw.githubusercontent.com/hashicorp/terraform-aws-consul/master/modules/install-consul/install-consul -O https://raw.githubusercontent.com/hashicorp/terraform-aws-consul/master/modules/run-consul/run-consul

chmod +x ./install-consul
chmod +x ./run-consul
/bin/bash ./install-consul %{ if version != "" }--version ${version} %{ endif}%{ if download-url != "" }--download-url ${download-url} %{ endif}%{ if path != "" }--path ${path} %{ endif}%{ if user != "" }--user ${user} %{ endif}
cp ./run-consul ${path}/bin/run-consul
%{ if enable-gossip-encryption }
local gossip-encrypt-key=`aws s3 cp s3://${bucket}/gossip_encrypt_key -`
%{ endif }
%{ if enable-rpc-encryption && ca-path == "" }
aws s3 cp s3://${bucket}/ca.pem $ca-path
aws s3 cp s3://${bucket}/ca_private_key.pem $ca-private-key-path --sse aws:kms --sse-kms-key-id=${bucketkms}
$path/bin/consul tls cert create -server -ca=$ca-path -key=$ca-private-key-path %{ if datacenter != "" }-dc=${datacenter} %{ endif }
cp %{ if datacenter != ""}${datacenter}%{ else }dc1%{ endif }-server-consul-0.pem $cert-file-path
cp %{ if datacenter != ""}${datacenter}%{ else }dc1%{ endif }-server-consul-0-key.pem $key-file-path
%{ endif }
/bin/bash $path/bin/run-consul %{ if server == true }--server %{ endif}%{ if client == true }--client %{ endif}%{ if config-dir != "" }--config-dir ${config-dir} %{ endif}%{ if data-dir != "" }--data-dir ${data-dir} %{ endif}%{ if systemd-stdout != "" }--systemd-stdout ${systemd-stdout} %{ endif}%{ if systemd-stderr != "" }--systemd-stderr ${systemd-stderr} %{ endif}%{ if bin-dir != "" }--bin-dir ${bin-dir} %{ endif}%{ if user != "" }--user ${user} %{ endif}%{ if cluster-tag-key != "" }--cluster-tag-key ${cluster-tag-key} %{ endif}%{ if cluster-tag-value != "" }--cluster-tag-value ${cluster-tag-value} %{ endif}%{ if datacenter != "" }--datacenter ${datacenter} %{ endif}%{ if autopilot-cleanup-dead-servers != "" }--autopilot-cleanup-dead-servers ${autopilot-cleanup-dead-servers} %{ endif}%{ if autopilot-last-contact-threshold != "" }--autopilot-last-contact-threshold ${autopilot-last-contact-threshold} %{ endif}%{ if autopilot-max-trailing-logs != "" }--autopilot-max-trailing-logs ${autopilot-max-trailing-logs} %{ endif}%{ if autopilot-server-stabilization-time != "" }--autopilot-server-stabilization-time ${autopilot-server-stabilization-time} %{ endif}%{ if autopilot-redundancy-zone-tag != "" }--autopilot-redundancy-zone-tag ${autopilot-redundancy-zone-tag} %{ endif}%{ if autopilot-disable-upgrade-migration != "" }--autopilot-disable-upgrade-migration ${autopilot-disable-upgrade-migration} %{ endif}%{ if autopilot-upgrade-version-tag != "" }--autopilot-upgrade-version-tag ${autopilot-upgrade-version-tag} %{ endif}%{ if enable-gossip-encryption }--enable-gossip-encryption --gossip-encryption-key $gossip-encrypt-key %{ endif}%{ if enable-rpc-encryption }--enable-rpc-encryption --ca-path $ca-path --cert-file-path $cert-file-path --key-file-path $key-file-path %{ endif}%{ if environment != "" }--environment ${environment} %{ endif}%{ if skip-consul-config != "" }--skip-consul-config ${skip-consul-config} %{ endif}%{ if recursor != "" }--recursor ${recursor} %{ endif}
%{ if consul_ent_license != ""}
local consul_ent_license=`aws s3 cp s3://${bucket}/gossip_encrypt_key - --sse aws:kms --sse-kms-key-id=${bucketkms}`
while [ curl http://127.0.0.1:8500/v1/status/leader -eq "" ] do
  echo "Waiting for Consul Cluster to start"
  sleep 3
done
$path/bin/consul license put $consul_ent_license
%{ endif }
