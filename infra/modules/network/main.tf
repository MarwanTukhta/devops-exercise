###########################################################
# AZs + CIDRs
###########################################################
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs       = slice(data.aws_availability_zones.available.names, 0, 2)
  lb_prefix = substr(var.name_prefix, 0, 12)

  public_cidrs = {
    (local.azs[0]) = cidrsubnet(var.vpc_cidr, 8, 0)
    (local.azs[1]) = cidrsubnet(var.vpc_cidr, 8, 1)
  }

  dmz_cidrs = {
    (local.azs[0]) = cidrsubnet(var.vpc_cidr, 8, 2)
    (local.azs[1]) = cidrsubnet(var.vpc_cidr, 8, 3)
  }

  private_cidrs = {
    (local.azs[0]) = cidrsubnet(var.vpc_cidr, 8, 10)
    (local.azs[1]) = cidrsubnet(var.vpc_cidr, 8, 11)
  }

  private_db_cidrs = {
    (local.azs[0]) = cidrsubnet(var.vpc_cidr, 8, 20)
    (local.azs[1]) = cidrsubnet(var.vpc_cidr, 8, 21)
  }

  private_cidrs_list    = values(local.private_cidrs)
  private_db_cidrs_list = values(local.private_db_cidrs)
}

###########################################################
# VPC + IGW
###########################################################
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-nat-eip"
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = values(aws_subnet.public)[0].id

  tags = {
    Name = "${var.name_prefix}-nat"
  }
}

###########################################################
# Subnets
###########################################################
resource "aws_subnet" "public" {
  for_each                = local.public_cidrs
  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = true

  tags = {
    Name                               = "${var.name_prefix}-protected-${each.key}"
    Tier                               = "protected-public"
    "kubernetes.io/role/elb"           = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

resource "aws_subnet" "dmz" {
  for_each                = local.dmz_cidrs
  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-dmz-${each.key}"
    Tier = "dmz"
  }
}

resource "aws_subnet" "private" {
  for_each          = local.private_cidrs
  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = {
    Name                               = "${var.name_prefix}-private-${each.key}"
    Tier                               = "private"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

resource "aws_subnet" "private_db" {
  for_each          = local.private_db_cidrs
  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = {
    Name = "${var.name_prefix}-private-db-${each.key}"
    Tier = "private"
  }
}

resource "aws_security_group" "public_alb" {
  name        = "${var.name_prefix}-public-alb-sg"
  description = "Security group for the public ALB."
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

###########################################################
# Network Firewall (DMZ)
###########################################################
resource "aws_networkfirewall_rule_group" "allow_http_ingress" {
  capacity = 100
  name     = "${var.name_prefix}-allow-http"
  type     = "STATEFUL"

  rule_group {
    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }

    rules_source {
      stateful_rule {
        action = "PASS"
        header {
          source           = "0.0.0.0/0"
          source_port      = "ANY"
          destination      = var.vpc_cidr
          destination_port = "80"
          protocol         = "TCP"
          direction        = "FORWARD"
        }
        rule_option {
          keyword  = "sid"
          settings = ["1"]
        }
      }

      stateful_rule {
        action = "PASS"
        header {
          source           = format("%s/32", aws_eip.nat.public_ip)
          source_port      = "ANY"
          destination      = "0.0.0.0/0"
          destination_port = "ANY"
          protocol         = "IP"
          direction        = "FORWARD"
        }
        rule_option {
          keyword  = "sid"
          settings = ["2"]
        }
      }

      stateful_rule {
        action = "PASS"
        header {
          source           = var.vpc_cidr
          source_port      = "ANY"
          destination      = "0.0.0.0/0"
          destination_port = "ANY"
          protocol         = "IP"
          direction        = "FORWARD"
        }
        rule_option {
          keyword  = "sid"
          settings = ["3"]
        }
      }
    }
  }
}

resource "aws_networkfirewall_firewall_policy" "this" {
  name = "${var.name_prefix}-fw-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateful_engine_options {
      rule_order = "STRICT_ORDER"
    }

    stateful_default_actions = ["aws:drop_strict"]

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.allow_http_ingress.arn
      priority     = 1
    }
  }
}

resource "aws_networkfirewall_firewall" "this" {
  name                = "${var.name_prefix}-fw"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.this.arn
  vpc_id              = aws_vpc.this.id

  dynamic "subnet_mapping" {
    for_each = aws_subnet.dmz
    content {
      subnet_id = subnet_mapping.value.id
    }
  }

  tags = {
    Name = "${var.name_prefix}-fw"
  }
}

locals {
  firewall_endpoint_ids = {
    for state in aws_networkfirewall_firewall.this.firewall_status[0].sync_states :
    state.availability_zone => state.attachment[0].endpoint_id
  }
}

###########################################################
# Route tables (protected public + dmz + private + igw ingress)
###########################################################
resource "aws_route_table" "public" {
  for_each = aws_subnet.public
  vpc_id   = aws_vpc.this.id
  depends_on = [aws_networkfirewall_firewall.this]

  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = local.firewall_endpoint_ids[each.key]
  }

  tags = {
    Name = "${var.name_prefix}-rt-protected-${each.key}"
  }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[each.key].id
}

resource "aws_route_table" "igw_ingress" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-rt-igw-ingress"
  }
}

resource "aws_route_table_association" "igw_ingress" {
  gateway_id     = aws_internet_gateway.this.id
  route_table_id = aws_route_table.igw_ingress.id
}

resource "aws_route" "igw_ingress_to_protected" {
  for_each               = aws_subnet.public
  route_table_id         = aws_route_table.igw_ingress.id
  destination_cidr_block = each.value.cidr_block
  vpc_endpoint_id        = local.firewall_endpoint_ids[each.key]
  depends_on             = [aws_networkfirewall_firewall.this]
}

resource "aws_route_table" "dmz" {
  for_each = aws_subnet.dmz
  vpc_id   = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.name_prefix}-rt-dmz-${each.key}"
  }
}

resource "aws_route_table_association" "dmz" {
  for_each       = aws_subnet.dmz
  subnet_id      = each.value.id
  route_table_id = aws_route_table.dmz[each.key].id
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id   = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = {
    Name = "${var.name_prefix}-rt-private-${each.key}"
  }
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_route_table" "private_db" {
  for_each = aws_subnet.private_db
  vpc_id   = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = {
    Name = "${var.name_prefix}-rt-private-db-${each.key}"
  }
}

resource "aws_route_table_association" "private_db" {
  for_each       = aws_subnet.private_db
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_db[each.key].id
}
