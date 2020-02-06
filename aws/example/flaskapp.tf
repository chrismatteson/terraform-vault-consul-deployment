# Setup customer application

resource "random_id" "project_tag" {
  byte_length = 4
}

resource "tls_private_key" "ssh" {
  algorithm   = "RSA"
  rsa_bits = "4096"
}

resource "aws_key_pair" "key" {
  key_name   = "${random_id.project_tag.hex}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

# Lookup most recent AMI
data "aws_ami" "latest-flask-image" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_vpc" "flask-vpc" {
  cidr_block = "172.16.0.0/16"
}

resource "aws_internet_gateway" "flask-gw" {
  vpc_id = aws_vpc.flask-vpc.id
}

resource "aws_default_route_table" "flask-table" {
  default_route_table_id = aws_vpc.flask-vpc.default_route_table_id
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_default_route_table.flask-table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.flask-gw.id
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.flask-vpc.id
  availability_zone       = data.aws_availability_zones.available.names[0]
  cidr_block              = "172.16.1.0/24"
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      "ProjectTag" = random_id.project_tag.hex
    },
  )
}

resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.flask-vpc.id
  availability_zone       = data.aws_availability_zones.available.names[1]
  cidr_block              = "172.16.2.0/24"
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      "ProjectTag" = random_id.project_tag.hex
    },
  )
}

resource "aws_default_security_group" "flask-vpc_default" {
  vpc_id = aws_vpc.flask-vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_instance" "web" {
  ami           = data.aws_ami.latest-flask-image.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet1.id
  key_name      = aws_key_pair.key.key_name
  iam_instance_profile = aws_iam_instance_profile.flask-instance_profile.id

  user_data = <<EOF
#!/bin/bash
sudo apt-get update -y
sudo apt-get install -y python3-flask
sudo apt-get install -y python3-pandas
sudo apt-get install -y python3-pymysql
sudo apt-get install -y python3-boto3

sudo useradd flask
sudo mkdir -p /opt/flask
sudo chown -R flask:flask /opt/flask
sudo git clone https://github.com/chrismatteson/terraform-chip-vault
cp -r terraform-chip-vault/flaskapp/* /opt/flask/

mysqldbcreds=$(cat <<MYSQLDBCREDS
{
  "username": "${aws_db_instance.database.username}",
  "password": "${aws_db_instance.database.password}",
  "hostname": "${aws_db_instance.database.address}"
}
MYSQLDBCREDS
)

echo -e "$mysqldbcreds" > /opt/flask/mysqldbcreds.json

systemd=$(cat <<SYSTEMD
[Unit]
Description=Flask App for CHIP Vault Certification
After=network.target

[Service]
User=flask
WorkingDirectory=/opt/flask
ExecStart=/usr/bin/python3 app.py
Restart=always

[Install]
WantedBy=multi-user.target
SYSTEMD
)

echo -e "$systemd" > /etc/systemd/system/flask.service

sudo systemctl daemon-reload
sudo systemctl enable flask.service
sudo systemctl restart flask.service
EOF

  tags = merge(
    var.tags,
    {
      "ProjectTag" = random_id.project_tag.hex
    },
  )
}

resource "aws_iam_role" "flask-instance_role" {
  name_prefix        = "${random_id.project_tag.hex}-instance-role"
  assume_role_policy = data.aws_iam_policy_document.flask-instance_role.json
}

data "aws_iam_policy_document" "flask-instance_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_instance_profile" "flask-instance_profile" {
  name_prefix = "${random_id.project_tag.hex}-flask-instance_profile"
  role        = aws_iam_role.flask-instance_role.name
}

resource "aws_iam_role_policy_attachment" "SystemsManager" {
  role       = aws_iam_role.flask-instance_role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_db_subnet_group" "db_subnet" {
  subnet_ids = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

  tags = merge(
    var.tags,
    {
      "ProjectTag" = random_id.project_tag.hex
    },
  )
}

resource "aws_db_instance" "database" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  name                   = "mydb"
  username               = "foo"
  password               = "foobarbaz"
  parameter_group_name   = "default.mysql5.7"
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.db_subnet.id
  vpc_security_group_ids = [aws_vpc.flask-vpc.default_security_group_id]
}

resource "aws_vpc_peering_connection" "bastion_flask_connectivity" {
  provider    = aws.region1
  peer_vpc_id = module.primary_cluster.bastion_vpc_id
  vpc_id      = aws_vpc.flask-vpc.id
  auto_accept = true
}

resource "aws_vpc_peering_connection" "vault_flask_connectivity" {
  peer_vpc_id = module.primary_cluster.vpc_id
  vpc_id      = aws_vpc.flask-vpc.id
  auto_accept = true
}

resource "aws_route" "flask_vault" {
  count                     = length(module.primary_cluster.public_subnets)
  route_table_id            = aws_default_route_table.flask-table.id
  destination_cidr_block    = element(module.primary_cluster.public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_flask_connectivity.id
}
resource "aws_route" "vault_flask" {
  count                     = length([aws_subnet.subnet1.cidr_block, aws_subnet.subnet2.cidr_block])
  route_table_id            = module.primary_cluster.route_table
  destination_cidr_block    = element([aws_subnet.subnet1.cidr_block, aws_subnet.subnet2.cidr_block], count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_flask_connectivity.id
}

resource "aws_route" "flask_bastion" {
  count                     = length(module.primary_cluster.bastion_public_subnets)
  route_table_id            = aws_default_route_table.flask-table.id
  destination_cidr_block    = element(module.primary_cluster.bastion_public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_flask_connectivity.id
}

resource "aws_route" "bastion_flask" {
  count                     = length([aws_subnet.subnet1.cidr_block, aws_subnet.subnet2.cidr_block])
  route_table_id            = module.primary_cluster.bastion_route_table
  destination_cidr_block    = element([aws_subnet.subnet1.cidr_block, aws_subnet.subnet2.cidr_block], count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_flask_connectivity.id
}
