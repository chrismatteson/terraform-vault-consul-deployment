#!/bin/bash 

readonly CONSUL_USER=%{ if consul_user != "" }${consul_user}%{else}"consul"%{endif}
readonly DOWNLOAD_PACKAGE_PATH="/tmp/consul.zip"
readonly SCRIPT_DIR="$(cd "$(dirname "$${BASH_SOURCE[0]}")" && pwd)"
readonly SYSTEM_BIN_DIR="/usr/local/bin"
readonly SCRIPT_NAME="$(basename "$0")"
readonly AWS_ASG_TAG_KEY="aws:autoscaling:groupName"
readonly CONSUL_CONFIG_FILE="default.json"
readonly CONSUL_GOSSIP_ENCRYPTION_CONFIG_FILE="gossip-encryption.json"
readonly CONSUL_RPC_ENCRYPTION_CONFIG_FILE="rpc-encryption.json"
readonly SYSTEMD_CONFIG_PATH="/etc/systemd/system"
readonly EC2_INSTANCE_METADATA_URL="http://169.254.169.254/latest/meta-data"
readonly EC2_INSTANCE_DYNAMIC_DATA_URL="http://169.254.169.254/latest/dynamic"
readonly MAX_RETRIES=30
readonly SLEEP_BETWEEN_RETRIES_SEC=10
readonly CONSUL_PATH=%{ if consul_path != "" }${consul_path}%{else}"/opt/consul"%{endif}
readonly CA_PATH=%{ if ca_path != "" }${ca_path}%{else}"$CONSUL_PATH/tls/ca/ca.pem"%{endif}
readonly CA_PRIVATE_KEY_PATH=$CONSUL_PATH/tls/ca/ca_private_key.pem
readonly CERT_FILE_PATH=%{ if cert_file_path != "" }${cert_file_path}%{else}"$CONSUL_PATH/tls/server.pem"%{endif}
readonly KEY_FILE_PATH=%{ if key_file_path != "" }${key_file_path}%{else}"$CONSUL_PATH/tls/key.pem"%{endif}
readonly DATACENTER=%{ if datacenter != "" }${datacenter}%{ else }dc1%{ endif }
readonly CONSUL_VERSION=%{ if consul_version != "" }${consul_version}%{ endif }
readonly CONSUL_DOWNLOAD_URL=%{ if consul_download_url != "" }${consul_download_url}%{ endif }
readonly AUTOPILOT_CLEANUP_DEAD_SERVERS=%{ if autopilot_cleanup_dead_servers != "" }${autopilot_cleanup_dead_servers}%{ else }"true"%{ endif }
readonly AUTOPILOT_LAST_CONTACT_THRESHOLD=%{ if autopilot_last_contact_threshold != "" }${autopilot_last_contact_threshold}%{ else }"200ms"%{ endif }
readonly AUTOPILOT_MAX_TRAILING_LOGS=%{ if autopilot_max_trailing_logs != "" }${autopilot_max_trailing_logs}%{ else }"250"%{ endif }
readonly AUTOPILOT_SERVER_STABILIZATION_TIME=%{ if autopilot_server_stabilization_time != "" }${autopilot_server_stabilization_time}%{ else }"10s"%{ endif }
readonly AUTOPILOT_REDUNDANCY_ZONE_TAG=%{ if autopilot_redundancy_zone_tag != "" }${autopilot_redundancy_zone_tag}%{ else }"az"%{ endif }
readonly AUTOPILOT_DISABLE_UPGRADE_MIGRATION=%{ if autopilot_disable_upgrade_migration != "" }${autopilot_disable_upgrade_migration}%{ else }"false"%{ endif }

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

function strip_prefix {
  local -r str="$1"
  local -r prefix="$2"
  echo "$${str#$prefix}"
}

function assert_not_empty {
  local -r arg_name="$1"
  local -r arg_value="$2"

  if [[ -z "$arg_value" ]]; then
    log_error "The value for '$arg_name' cannot be empty"
    print_usage
    exit 1
  fi
}

function assert_either_or {
  local -r arg1_name="$1"
  local -r arg1_value="$2"
  local -r arg2_name="$3"
  local -r arg2_value="$4"

  if [[ -z "$arg1_value" && -z "$arg2_value" ]]; then
    log_error "Either the value for '$arg1_name' or '$arg2_name' must be passed, both cannot be empty"
    print_usage
    exit 1
  fi
}

# A retry function that attempts to run a command a number of times and returns the output
function retry {
  local -r cmd="$1"
  local -r description="$2"
  local -r max_tries="$3"

  for i in $(seq 1 $max_tries); do
    log_info "$description"

    # The boolean operations with the exit status are there to temporarily circumvent the "set -e" at the
    # beginning of this script which exits the script immediatelly for error status while not losing the exit status code
    output=$(eval "$cmd") && exit_status=0 || exit_status=$?
    log_info "$output"
    if [[ $exit_status -eq 0 ]]; then
      echo "$output"
      return
    fi
    log_warn "$description failed. Will sleep for 10 seconds and try again."
    sleep 10
  done;

  log_error "$description failed after $max_tries attempts."
  exit $exit_status
}

function has_yum {
  [ -n "$(command -v yum)" ]
}

function has_apt_get {
  [ -n "$(command -v apt-get)" ]
}

function install_dependencies {
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
}

function user_exists {
  local -r username="$1"
  id "$username" >/dev/null 2>&1
}

function create_consul_user {
  local -r username="$1"

  if $(user_exists "$username"); then
    echo "User $username already exists. Will not create again."
  else
    log_info "Creating user named $username"
    sudo useradd "$username"
  fi
}

function create_consul_install_paths {
  local -r path="$1"
  local -r username="$2"

  log_info "Creating install dirs for Consul at $path"
  sudo mkdir -p "$path"
  sudo mkdir -p "$path/bin"
  sudo mkdir -p "$path/config"
  sudo mkdir -p "$path/data"
  sudo mkdir -p "$path/tls/ca"

  log_info "Changing ownership of $path to $username"
  sudo chown -R "$username:$username" "$path"
}

function fetch_binary {
  local -r version="$1"
  local download_url="$2"

  if [[ -z "$download_url" && -n "$version" ]];  then
    download_url="https://releases.hashicorp.com/consul/$${version}/consul_$${version}_linux_amd64.zip"
  fi

  retry \
    "curl -o '$DOWNLOAD_PACKAGE_PATH' '$download_url' --location --silent --fail --show-error" \
    "Downloading Consul to $DOWNLOAD_PACKAGE_PATH" \
    5
}

function install_binary {
  local -r install_path="$1"
  local -r username="$2"

  local -r bin_dir="$install_path/bin"
  local -r consul_dest_path="$bin_dir/consul"

  unzip -d /tmp "$DOWNLOAD_PACKAGE_PATH"

  log_info "Moving Consul binary to $consul_dest_path"
  sudo mv "/tmp/consul" "$consul_dest_path"
  sudo chown "$username:$username" "$consul_dest_path"
  sudo chmod a+x "$consul_dest_path"

  local -r symlink_path="$SYSTEM_BIN_DIR/consul"
  if [[ -f "$symlink_path" ]]; then
    log_info "Symlink $symlink_path already exists. Will not add again."
  else
    log_info "Adding symlink to $consul_dest_path in $symlink_path"
    sudo ln -s "$consul_dest_path" "$symlink_path"
  fi
}

function lookup_path_in_instance_metadata {
  local -r path="$1"
  curl --silent --show-error --location "$EC2_INSTANCE_METADATA_URL/$path/"
}

function lookup_path_in_instance_dynamic_data {
  local -r path="$1"
  curl --silent --show-error --location "$EC2_INSTANCE_DYNAMIC_DATA_URL/$path/"
}

function get_instance_ip_address {
  lookup_path_in_instance_metadata "local-ipv4"
}

function get_instance_id {
  lookup_path_in_instance_metadata "instance-id"
}

function get_instance_region {
  lookup_path_in_instance_dynamic_data "instance-identity/document" | jq -r ".region"
}

function get_instance_tags {
  local -r instance_id="$1"
  local -r instance_region="$2"
  local tags=""
  local count_tags=""

  log_info "Looking up tags for Instance $instance_id in $instance_region"
  for (( i=1; i<="$MAX_RETRIES"; i++ )); do
    tags=$(aws ec2 describe-tags \
      --region "$instance_region" \
      --filters "Name=resource-type,Values=instance" "Name=resource-id,Values=$${instance_id}")
    count_tags=$(echo $tags | jq -r ".Tags? | length")
    if [[ "$count_tags" -gt 0 ]]; then
      log_info "This Instance $instance_id in $instance_region has Tags."
      echo "$tags"
      return
    else
      log_warn "This Instance $instance_id in $instance_region does not have any Tags."
      log_warn "Will sleep for $SLEEP_BETWEEN_RETRIES_SEC seconds and try again."
      sleep "$SLEEP_BETWEEN_RETRIES_SEC"
    fi
  done

  log_error "Could not find Instance Tags for $instance_id in $instance_region after $MAX_RETRIES retries."
  exit 1
}

function get_asg_size {
  local -r asg_name="$1"
  local -r aws_region="$2"
  local asg_json=""

  log_info "Looking up the size of the Auto Scaling Group $asg_name in $aws_region"
  asg_json=$(aws autoscaling describe-auto-scaling-groups --region "$aws_region" --auto-scaling-group-names "$asg_name")
  echo "$asg_json" | jq -r '.AutoScalingGroups[0].DesiredCapacity'
}

function get_cluster_size {
  local -r instance_tags="$1"
  local -r aws_region="$2"

  local asg_name=""
  asg_name=$(get_tag_value "$instance_tags" "$AWS_ASG_TAG_KEY")
  if [[ -z "$asg_name" ]]; then
    log_warn "This EC2 Instance does not appear to be part of an Auto Scaling Group, so cannot determine cluster size. Setting cluster size to 1."
    echo 1
  else
    get_asg_size "$asg_name" "$aws_region"
  fi
}

# Get the value for a specific tag from the tags JSON returned by the AWS describe-tags:
# https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-tags.html
function get_tag_value {
  local -r tags="$1"
  local -r tag_key="$2"

  echo "$tags" | jq -r ".Tags[] | select(.Key == \"$tag_key\") | .Value"
}

function assert_is_installed {
  local -r name="$1"

  if [[ ! $(command -v $${name}) ]]; then
    log_error "The binary '$name' is required by this script but is not installed or in the system's PATH."
    exit 1
  fi
}

function split_by_lines {
  local prefix="$1"
  shift

  for var in "$@"; do
    echo "$${prefix}$${var}"
  done
}

function generate_consul_config {
  local -r server="$${1}"
  local -r config_dir="$${2}"
  local -r user="$${3}"
  local -r cluster_tag_key="$${4}"
  local -r cluster_tag_value="$${5}"
  local -r datacenter="$${6}"
  local -r enable_gossip_encryption="$${7}"
  local -r gossip_encryption_key="$${8}"
  local -r enable_rpc_encryption="$${9}"
  local -r ca_path="$${10}"
  local -r cert_file_path="$${11}"
  local -r key_file_path="$${12}"
  local -r enable_acls="$${13}"
  local -r cleanup_dead_servers="$${14}"
  local -r last_contact_threshold="$${15}"
  local -r max_trailing_logs="$${16}"
  local -r server_stabilization_time="$${17}"
  local -r redundancy_zone_tag="$${18}"
  local -r disable_upgrade_migration="$${19}"
  local -r upgrade_version_tag=$${20}
  local -r config_path="$config_dir/$CONSUL_CONFIG_FILE"

  shift 20
  local -r recursors=("$@")

  local instance_id=""
  local instance_ip_address=""
  local instance_region=""
  local ui="false"

  instance_id=$(get_instance_id)
  instance_ip_address=$(get_instance_ip_address)
  instance_region=$(get_instance_region)

  local retry_join_json=""
  if [[ -z "$cluster_tag_key" || -z "$cluster_tag_value" ]]; then
    log_warn "Either the cluster tag key ($cluster_tag_key) or value ($cluster_tag_value) is empty. Will not automatically try to form a cluster based on EC2 tags."
  else
    retry_join_json=$(cat <<EOF
"retry_join": ["provider=aws region=$instance_region tag_key=$cluster_tag_key tag_value=$cluster_tag_value"],
EOF
)
  fi

  local recursors_config=""
  if (( $${#recursors[@]} != 0 )); then
        recursors_config="\"recursors\" : [ "
        for recursor in $${recursors[@]}
        do
            recursors_config="$${recursors_config}\"$${recursor}\", "
        done
        recursors_config=$(echo "$${recursors_config}"| sed 's/, $//')" ],"
  fi

  local bootstrap_expect=""
  if [[ "$server" == "true" ]]; then
    local instance_tags=""
    local cluster_size=""

    instance_tags=$(get_instance_tags "$instance_id" "$instance_region")
    cluster_size=$(get_cluster_size "$instance_tags" "$instance_region")

    bootstrap_expect="\"bootstrap_expect\": $((($cluster_size+1)/2)),"
    ui="true"
  fi

  local autopilot_configuration=$(cat <<EOF
"autopilot": {
  "cleanup_dead_servers": $cleanup_dead_servers,
  "last_contact_threshold": "$last_contact_threshold",
  "max_trailing_logs": $max_trailing_logs,
  "server_stabilization_time": "$server_stabilization_time",
  "redundancy_zone_tag": "$redundancy_zone_tag",
  "disable_upgrade_migration": $disable_upgrade_migration,
  "upgrade_version_tag": "$upgrade_version_tag"
},
EOF
)

  local gossip_encryption_configuration=""
  if [[ "$enable_gossip_encryption" == "true" && ! -z "$gossip_encryption_key" ]]; then
    log_info "Creating gossip encryption configuration"
    gossip_encryption_configuration="\"encrypt\": \"$gossip_encryption_key\","
  fi

  local rpc_encryption_configuration=""
  if [[ "$enable_rpc_encryption" == "true" && ! -z "$ca_path" && ! -z "$cert_file_path" && ! -z "$key_file_path" ]]; then
    log_info "Creating RPC encryption configuration"
    rpc_encryption_configuration=$(cat <<EOF
"verify_outgoing": true,
"verify_incoming": true,
"ca_path": "$ca_path",
"cert_file": "$cert_file_path",
"key_file": "$key_file_path",
EOF
)
  fi

  local acl_configuration=""
  if [ "$enable_acls" == "true" ]; then
    log_info "Creating ACL configuration"
    acl_configuration=$(cat <<EOF
"acl": {
  "enabled": true,
  "default_policy": "deny",
  "enable_token_persistence": true
},
EOF
)
  fi

  local node_meta_configuration=""
  if [ "$node_meta" != "" ]; then
    log_info "Creating node-meta configuration"
    node_meta_configuration=$(cat <<EOF
"node_meta": $${node_meta},
EOF
)
  fi

  log_info "Creating default Consul configuration"
  local default_config_json=$(cat <<EOF
{
  "advertise_addr": "$instance_ip_address",
  "bind_addr": "$instance_ip_address",
  $bootstrap_expect
  "client_addr": "0.0.0.0",
  "datacenter": "$datacenter",
  "node_name": "$instance_id",
  $recursors_config
  $retry_join_json
  "server": $server,
  $gossip_encryption_configuration
  $rpc_encryption_configuration
  $autopilot_configuration
  $acl_configuration
  $node_meta_configuration
  "ui": $ui
}
EOF
)
  log_info "Installing Consul config file in $config_path"
  echo "$default_config_json" | jq '.' > "$config_path"
  chown "$user:$user" "$config_path"
}

function generate_systemd_config {
  local -r service="$1"
  local -r systemd_config_path="$2"
  local -r user="$3"
  local -r exec_start="$4"
  local -r config_dir="$5"
  local -r config_file="$6"
  local -r bin_dir="$7"
  local -r data_dir="$8"
  shift 7
  local -r config_path="$config_dir/$config_file"
  if [[ -z "$data_dir" ]]; then
    local -r exec_string="$${exec_start} -config-dir $${config_dir}"
  else
    local -r exec_string="$${exec_start} -config-dir $${config_dir} -data-dir $${data_dir}"
  fi

  log_info "Creating systemd config file to run Consul in $systemd_config_path/$service.service"

  local -r unit_config=$(cat <<EOF
[Unit]
Description="HashiCorp $service"
Documentation=https://www.hashicorp.com/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=$config_path
EOF
)

  local -r service_config=$(cat <<EOF
[Service]
Type=notify
User=$user
Group=$user
ExecStart=$exec_string
ExecReload=$bin_dir/$service reload
KillMode=process
Restart=on-failure
LimitNOFILE=65536
EOF
)

  local -r install_config=$(cat <<EOF
[Install]
WantedBy=multi-user.target
EOF
)

  echo -e "$unit_config" > "$systemd_config_path/$service.service"
  echo -e "$service_config" >> "$systemd_config_path/$service.service"
  echo -e "$install_config" >> "$systemd_config_path/$service.service"
}

function start_consul {
  log_info "Reloading systemd config and starting Consul"

  sudo systemctl daemon-reload
  sudo systemctl enable consul.service
  sudo systemctl restart consul.service
}

function configure_gossip_encryption {
  local -r bucket="$1"
  local -r bucketkms="$2"
  local -r path="$3"

  aws s3 ls s3://${bucket}/gossip_encrypt_key
  ec=$?
  case $ec in
    0) log_info "Gossip Encryption Key already exists"
       gossip_encrypt_key=`aws s3 cp s3://${bucket}/gossip_encrypt_key - --sse aws:kms --sse-kms-key-id=${bucketkms}`
    ;;
    1) log_info "Creating Gossip Encryption Key"
       gossip_encrypt_key=`$path/bin/consul keygen`
       echo  $gossip_encrypt_key > gossip_encrypt_key
       aws s3 cp gossip_encrypt_key s3://${bucket}/gossip_encrypt_key --sse aws:kms --sse-kms-key-id=${bucketkms}
       rm gossip_encrypt_key
    ;;
    *) log_error "Error, aws s3 ls for gossip_encrypt_key did not return 0 or 1, but instead $ec"
    ;;
  esac
}

function create_ca {
  local -r bucket="$1"
  local -r bucketkms="$2"
  local -r path="$3"
  local -r ca_path="$4"
  local -r datacenter="$5"
  local -r cert_file_path="$6"
  local -r key_file_path="$7"

  ca_private_key_path=$path/tls/ca/ca_private_key.pem

  aws s3 ls s3://$bucket/consul-agent-ca-key.pem
  ec=$?
  case $ec in
    0) log_info "Consul CA already exists"
       aws s3 cp s3://$bucket/consul-agent-ca.pem $ca_path
       aws s3 cp s3://$bucket/consul-agent-ca-key.pem $ca_private_key_path --sse aws:kms --sse-kms-key-id=$bucketkms
    ;;
    1) log_info "Creating CA"
       $path/bin/consul tls ca create
       cp consul-agent-ca.pem $ca_path
       aws s3 cp consul-agent-ca.pem s3://$bucket/consul-agent-ca.pem
       cp consul-agent-ca-key.pem $ca_private_key_path
       aws s3 cp consul-agent-ca-key.pem s3://$bucket/consul-agent-ca-key.pem --sse aws:kms --sse-kms-key-id=$bucketkms
    ;;
    *) log_error "Error, aws s3 ls for consul-agent-ca-key.pem did not return 0 or 1, but instead $ec"
    ;;
  esac
  $path/bin/consul tls cert create -server -ca=$ca_path -key=$ca_private_key_path -dc=$datacenter
  cp $datacenter-server-consul-0.pem $cert_file_path
  cp $datacenter-server-consul-0-key.pem $key_file_path
}

function enable_acls {
  local -r bucket="$1"
  local -r bucketkms="$2"
  local -r path="$3"

  log_info "Bootstrapping ACLs"
  curl localhost:8500/v1/status/leader | grep `curl http://169.254.169.254/latest/meta-data/local-ipv4`
  ec=$?
  case $ec in
    0) log_info "This is the leader"
    ;;
    1) log_info "This is a follower"
       sleep 20
    ;;
    *) log_error "Error, curl for cluster leader did not return 0 or 1, but instead $ec"
    ;;
  esac

  aws s3 ls s3://${bucket}/consul-http-token
  ec=$?
  case $ec in
    0) log_info "Consul ACLs already bootstrapped"
       consul_http_token=`aws s3 cp s3://${bucket}/consul-http-token - --sse aws:kms --sse-kms-key-id=${bucketkms}`
       sed -i "/\"acl\":/a \"tokens\": { \"agent\":  \"$consul_http_token\" }," /opt/consul/config/default.json
       service consul restart
    ;;
    1) log_info "Bootstrapping ACLs"
       consul_http_token=`$path/bin/consul acl bootstrap | grep SecretID | sed 's/\(SecretID:\)[ ]*\([a-z1-9-]*\)/\2/'`
       echo $consul_http_token > consul-http-token
       aws s3 cp consul-http-token s3://${bucket}/consul-http-token --sse aws:kms --sse-kms-key-id=${bucketkms}
       rm consul-http-token
       sed -i "/\"acl\":/a \"tokens\": { \"agent\":  \"$consul_http_token\" }," /opt/consul/config/default.json
       service consul restart
    ;;
    *) log_error "Error, aws s3 ls for consul-http-token did not return 0 or 1, but instead $ec"
    ;;
  esac
}

function install_license {
  local -r consul_license_arn="$1"
  local -r consul_http_token="$2"

  log_info "Installing Enterprise License"
  aws configure set region $(get_instance_region)
  if [[ -z $consul_http_token ]]; then
    aws lambda invoke --function-name $consul_license_arn  --payload "{\"consul_server\": \"http://`curl http://169.254.169.254/latest/meta-data/local-ipv4`\"}" /dev/null
  else
    aws lambda invoke --function-name $consul_license_arn  --payload "{\"consul_server\": \"http://`curl http://169.254.169.254/latest/meta-data/local-ipv4`\", \"token\": \"$${consul_http_token}\"}" /dev/null
  fi
}

function configure_backups {
  local -r consul_backup_bucket="$1"
  local -r user="$2"
  local -r path="$3"
  local -r consul_http_token="$4"

  log_info "Configure Consul Backup"
  consul_backup_config=$(cat <<EOF
{
  "snapshot_agent": {
    "http_addr": "127.0.0.1:8500",
    "token": "$${consul_http_token}",
    "log": {
      "level": "INFO",
      "enable_syslog": false,
      "syslog_facility": "LOCAL0"
    },
    "snapshot": {
        "interval": "1h",
        "retain": 30,
        "stale": false,
        "service": "consul-snapshot",
        "deregister_after": "72h",
        "lock_key": "consul-snapshot/lock",
        "max_failures": 3
      },
      "aws_storage": {
        "s3_bucket": "$${consul_backup_bucket}",
        "s3_region": `curl http://169.254.169.254/latest/dynamic/instance-identity/document | jq .region`, 
        "s3_key_prefix": "consul-snapshot",
        "s3_server_side_encryption":false
      }
    }
  }
EOF
)
  echo -e "$consul_backup_config" > /opt/consul/config/backup.json

  generate_systemd_config "consulbackup" \
    "$SYSTEMD_CONFIG_PATH" \
    "$user" \
    "$path/bin/consul snapshot agent" \
    "$path/config" \
    "backup.json" \
    "$path/bin"
  service consulbackup restart
}

function main {
  log_info "Starting Consul install"
  install_dependencies
  create_consul_user "$CONSUL_USER"
  create_consul_install_paths "$CONSUL_PATH" "$CONSUL_USER"

  fetch_binary "$CONSUL_VERSION" "$CONSUL_DOWNLOAD_URL"
  install_binary "$CONSUL_PATH" "$CONSUL_USER"

  if command -v consul; then
    log_info "Consul install complete!";
  else
    log_info "Could not find consul command. Aborting.";
    exit 1;
  fi

  %{ if enable_gossip_encryption }
  configure_gossip_encryption ${bucket} ${bucketkms} "$CONSUL_PATH"
  %{ endif }
  %{ if enable_rpc_encryption && ca_path == "" }
  create_ca ${bucket} ${bucketkms} "$CONSUL_PATH" "$CA_PATH" "$DATACENTER" "$CERT_FILE_PATH" "$KEY_FILE_PATH"
  %{ endif }
  %{ if autopilot_redundancy_zone_tag != ""}
  node_meta="{ \"${autopilot_redundancy_zone_tag}\": \"`curl http://169.254.169.254/latest/meta-data/placement/availability-zone`\" }"
  %{ endif }

  assert_is_installed "systemctl"
  assert_is_installed "aws"
  assert_is_installed "curl"
  assert_is_installed "jq"

  if [[ -z "$config_dir" ]]; then
    config_dir=$(cd "$CONSUL_PATH/config" && pwd)
  fi

  if [[ -z "$data_dir" ]]; then
    data_dir=$(cd "$CONSUL_PATH/data" && pwd)
  fi

  # If $systemd_stdout and/or $systemd_stderr are empty, we leave them empty so that generate_systemd_config will use systemd's defaults (journal and inherit, respectively)

  generate_consul_config true \
    "$CONSUL_PATH/config" \
    "$user" \
    ${cluster_tag_key} \
    ${cluster_tag_value} \
    "$DATACENTER" \
    ${enable_gossip_encryption} \
    "$gossip_encrypt_key" \
    "$enable_rpc_encryption" \
    "$ca_path" \
    "$cert_file_path" \
    "$key_file_path" \
    ${enable_acls} \
    "$AUTOPILOT_CLEANUP_DEAD_SERVERS" \
    "$AUTOPILOT_LAST_CONTACT_THRESHOLD" \
    "$AUTOPILOT_MAX_TRAILING_LOGS" \
    "$AUTOPILOT_SERVER_STABILIZATION_TIME" \
    "$AUTOPILOT_REDUNDANCY_ZONE_TAG" \
    "$AUTOPILOT_DISABLE_UPGRADE_MIGRATION" \
    "$AUTOPILOT_UPGRADE_VERSION_TAG" \
    "$${recursors[@]}"

  generate_systemd_config "consul" \
    "$SYSTEMD_CONFIG_PATH" \
    "$user" \
    "$CONSUL_PATH/bin/consul agent" \
    "$CONSUL_PATH/config" \
    "default.json" \
    "$CONSUL_PATH/bin" \
    "$CONSUL_PATH/data"
  start_consul

  log_info "Wait for cluster to load"
  retry "curl localhost:8500/v1/status/leader | grep :" "Waiting for cluster leader" 100

  %{ if enable_acls }
  enable_acls ${bucket} ${bucketkms} $CONSUL_PATH
  %{ endif }

  %{ if consul_license_arn != "" }
  install_license ${consul_license_arn} $consul_http_token
  configure_backups ${consul_backup_bucket} $CONSUL_USER $CONSUL_PATH $consul_http_token
  %{ endif }

}

main $@
