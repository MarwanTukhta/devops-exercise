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
    Name                               = "${var.name_prefix}-public-${each.key}"
    Tier                               = "public"
    "kubernetes.io/role/elb"           = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
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

###########################################################
# Route tables (public + private)
###########################################################
resource "aws_route_table" "public" {
  for_each = aws_subnet.public
  vpc_id   = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.name_prefix}-rt-public-${each.key}"
  }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[each.key].id
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
