data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

data "aws_subnet" "private" {
  for_each = {
    for index, subnet_id in var.private_subnet_ids :
    index => subnet_id
  }
  id = each.value
}

locals {
  private_subnet_cidrs = values(data.aws_subnet.private)[*].cidr_block
}

resource "aws_security_group" "cockroachdb" {
  name        = "${var.name_prefix}-cockroachdb-sg"
  description = "CockroachDB access from private subnets only."
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 26257
    to_port     = 26257
    protocol    = "tcp"
    cidr_blocks = local.private_subnet_cidrs
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = local.private_subnet_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-cockroachdb-sg"
  }
}

resource "aws_instance" "cockroachdb" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.cockroach_instance_type
  subnet_id                   = var.db_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.cockroachdb.id]
  key_name                    = var.cockroach_key_name
  associate_public_ip_address = false

  root_block_device {
    volume_size = var.cockroach_root_volume_gb
  }

  tags = {
    Name = "${var.name_prefix}-cockroachdb"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    curl -fsSL https://binaries.cockroachdb.com/cockroach-v24.2.0.linux-amd64.tgz -o /tmp/crdb.tgz
    tar -xzf /tmp/crdb.tgz -C /tmp
    install /tmp/cockroach-v24.2.0.linux-amd64/cockroach /usr/local/bin/cockroach

    useradd -r -s /sbin/nologin cockroach || true
    mkdir -p /var/lib/cockroach /etc/cockroach
    chown -R cockroach:cockroach /var/lib/cockroach /etc/cockroach

    cat >/etc/systemd/system/cockroach.service <<'UNIT'
    [Unit]
    Description=CockroachDB
    After=network-online.target
    Wants=network-online.target

    [Service]
    User=cockroach
    ExecStart=/usr/local/bin/cockroach start-single-node --insecure --store=/var/lib/cockroach --listen-addr=0.0.0.0:26257 --http-addr=0.0.0.0:8080
    Restart=always
    LimitNOFILE=35000

    [Install]
    WantedBy=multi-user.target
    UNIT

    %{ if var.cockroach_ssh_password != null }
    cat >/etc/ssh/sshd_config.d/60-password-auth.conf <<'SSHCONF'
    PasswordAuthentication yes
    KbdInteractiveAuthentication no
    SSHCONF

    chpasswd <<'PASSWD'
    ec2-user:${var.cockroach_ssh_password}
    PASSWD

    systemctl restart sshd
    %{ endif }

    systemctl daemon-reload
    systemctl enable --now cockroach
  EOF
}

resource "aws_lb" "cockroachdb" {
  name               = "${substr(var.name_prefix, 0, 12)}-db-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.db_subnet_ids

  tags = {
    Name = "${var.name_prefix}-cockroachdb-nlb"
  }
}

resource "aws_lb_target_group" "cockroachdb_26257" {
  name        = "${substr(var.name_prefix, 0, 12)}-db-26257"
  port        = 26257
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    protocol            = "TCP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 15
  }
}

resource "aws_lb_target_group" "cockroachdb_8080" {
  name        = "${substr(var.name_prefix, 0, 12)}-db-8080"
  port        = 8080
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    protocol            = "TCP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 15
  }
}

resource "aws_lb_target_group_attachment" "cockroachdb_26257" {
  target_group_arn = aws_lb_target_group.cockroachdb_26257.arn
  target_id        = aws_instance.cockroachdb.id
  port             = 26257
}

resource "aws_lb_target_group_attachment" "cockroachdb_8080" {
  target_group_arn = aws_lb_target_group.cockroachdb_8080.arn
  target_id        = aws_instance.cockroachdb.id
  port             = 8080
}

resource "aws_lb_listener" "cockroachdb_26257" {
  load_balancer_arn = aws_lb.cockroachdb.arn
  port              = 26257
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cockroachdb_26257.arn
  }
}

resource "aws_lb_listener" "cockroachdb_8080" {
  load_balancer_arn = aws_lb.cockroachdb.arn
  port              = 8080
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cockroachdb_8080.arn
  }
}
