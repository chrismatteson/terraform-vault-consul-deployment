#!/bin/bash 

function log {
  local -r level="$1"
  local -r message="$2"
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "$${timestamp} [$${level}] [$SCRIPT_NAME] $${message}"
}

function log_info {
  local -r message="$1"
  log "INFO" "$message"
}

function log_warn {
  local -r message="$1"
  log "WARN" "$message"
}

function log_error {
  local -r message="$1"
  log "ERROR" "$message"
}

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

path=%{ if path != "" }${path}%{else}"/opt/consul"%{endif}
ca_path=%{ if ca_path != "" }${ca_path}%{else}"$path/tls/ca/ca.pem"%{endif}
ca_private_key_path=$path/tls/ca/ca_private_key.pem
cert_file_path=%{ if cert_file_path != "" }${cert_file_path}%{else}"$path/tls/server.pem"%{endif}
key_file_path=%{ if key_file_path != "" }${key_file_path}%{else}"$path/tls/key.pem"%{endif}

curl -O https://raw.githubusercontent.com/chrismatteson/terraform-aws-consul/master/modules/install-consul/install-consul -O https://raw.githubusercontent.com/chrismatteson/terraform-aws-consul/master/modules/run-consul/run-consul

chmod +x ./install-consul
chmod +x ./run-consul
cp ./run-consul ../run-consul/run-consul
/bin/bash ./install-consul %{ if version != "" }--version ${version} %{ endif}%{ if download_url != "" }--download_url ${download_url} %{ endif}%{ if path != "" }--path ${path} %{ endif}%{ if user != "" }--user ${user} %{ endif}
cp ./run-consul ${path}/bin/run-consul
%{ if enable_gossip_encryption }
aws s3 ls s3://${bucket}/gossip_encrypt_key
ec=$?
case $ec in
  0) echo "Gossip Encryption Key already exists"
     gossip_encrypt_key=`aws s3 cp s3://${bucket}/gossip_encrypt_key - --sse aws:kms --sse-kms-key-id=${bucketkms}`
  ;;
  1) echo "Gossip Encryption Key doesn't exist, creating"
     gossip_encrypt_key=`$path/bin/consul keygen`
     echo  $gossip_encrypt_key > gossip_encrypt_key
     aws s3 cp gossip_encrypt_key s3://${bucket}/gossip_encrypt_key --sse aws:kms --sse-kms-key-id=${bucketkms}
     rm gossip_encrypt_key
  ;;
  *) echo "Error, aws s3 ls for gossip_encrypt_key did not return 0 or 1, but instead $ec"
  ;;
esac
%{ endif }
%{ if enable_rpc_encryption && ca_path == "" }
aws s3 ls s3://${bucket}/consul-agent-ca-key.pem
ec=$?
case $ec in
  0) echo "Consul CA already exists"
     aws s3 cp s3://${bucket}/consul-agent-ca.pem $ca_path
     aws s3 cp s3://${bucket}/consul-agent-ca-key.pem $ca_private_key_path --sse aws:kms --sse-kms-key-id=${bucketkms}
  ;;
  1) echo "Consul CA doesn't exist, creating"
     $path/bin/consul tls ca create
     cp consul-agent-ca.pem $ca_path
     aws s3 cp consul-agent-ca.pem s3://${bucket}/consul-agent-ca.pem
     cp consul-agent-ca-key.pem $ca_private_key_path
     aws s3 cp consul-agent-ca-key.pem s3://${bucket}/consul-agent-ca-key.pem --sse aws:kms --sse-kms-key-id=${bucketkms}
  ;;
  *) echo "Error, aws s3 ls for gossip_encrypt_key did not return 0 or 1, but instead $ec"
  ;;
esac
$path/bin/consul tls cert create -server -ca=$ca_path -key=$ca_private_key_path %{ if datacenter != "" }-dc=${datacenter} %{ endif }
cp %{ if datacenter != ""}${datacenter}%{ else }dc1%{ endif }-server-consul-0.pem $cert_file_path
cp %{ if datacenter != ""}${datacenter}%{ else }dc1%{ endif }-server-consul-0-key.pem $key_file_path
%{ endif }
%{ if autopilot_redundancy_zone_tag != ""}
node_meta="{ \"${autopilot_redundancy_zone_tag}\": \"`curl http://169.254.169.254/latest/meta-data/placement/availability-zone`\" }"
%{ endif }
/bin/bash $path/bin/run-consul %{ if server == true }--server %{ endif}%{ if client == true }--client %{ endif}%{ if config_dir != "" }--config-dir ${config_dir} %{ endif}%{ if data_dir != "" }--data-dir ${data_dir} %{ endif}%{ if systemd_stdout != "" }--systemd-stdout ${systemd_stdout} %{ endif}%{ if systemd_stderr != "" }--systemd-stderr ${systemd_stderr} %{ endif}%{ if bin_dir != "" }--bin-dir ${bin_dir} %{ endif}%{ if user != "" }--user ${user} %{ endif}%{ if cluster_tag_key != "" }--cluster-tag-key ${cluster_tag_key} %{ endif}%{ if cluster_tag_value != "" }--cluster-tag-value ${cluster_tag_value} %{ endif}%{ if datacenter != "" }--datacenter ${datacenter} %{ endif}%{ if autopilot_cleanup_dead_servers != "" }--autopilot-cleanup-dead-servers ${autopilot_cleanup_dead_servers} %{ endif}%{ if autopilot_last_contact_threshold != "" }--autopilot-last-contact-threshold ${autopilot_last_contact_threshold} %{ endif}%{ if autopilot_max_trailing_logs != "" }--autopilot-max-trailing-logs ${autopilot_max_trailing_logs} %{ endif}%{ if autopilot_server_stabilization_time != "" }--autopilot-server-stabilization-time ${autopilot_server_stabilization_time} %{ endif}%{ if autopilot_redundancy_zone_tag != "" }--autopilot-redundancy-zone-tag ${autopilot_redundancy_zone_tag} --node-meta "$node_meta" %{ endif}%{ if autopilot_disable_upgrade_migration != "" }--autopilot-disable-upgrade-migration ${autopilot_disable_upgrade_migration} %{ endif}%{ if autopilot_upgrade_version_tag != "" }--autopilot-upgrade-version-tag ${autopilot_upgrade_version_tag} %{ endif}%{ if enable_gossip_encryption }--enable-gossip-encryption --gossip-encryption-key $gossip_encrypt_key %{ endif}%{ if enable_rpc_encryption }--enable-rpc-encryption --ca-path $ca_path --cert-file-path $cert_file_path --key-file-path $key_file_path %{ endif}%{ if environment != "" }--environment ${environment} %{ endif }%{ if skip_consul_config != "" }--skip-consul-config ${skip_consul_config} %{ endif}%{ if recursor != "" }--recursor ${recursor} %{ endif}%{ if enable_acls }--enable-acls %{ endif }
%{ if consul_ent_license != ""}
echo "Installing Enterprise License"
consul_ent_license=`aws s3 cp s3://${bucket}/consul_license - --sse aws:kms --sse-kms-key-id=${bucketkms}`
while [ `curl http://127.0.0.1:8500/v1/status/leader` == "" ]
do
  echo "Waiting for Consul Cluster to start"
  sleep 3
done
$path/bin/consul license put $consul_ent_license
%{ endif }
