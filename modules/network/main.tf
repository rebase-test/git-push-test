###############################################
# VPC
###############################################
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.name}-vpc"
  })
}

###############################################
# Internet Gateway (Public Subnet → 인터넷)
###############################################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-igw"
  })
}

###############################################
# Subnets (Public / Private-App / Private-DB / Private-Infra)
###############################################
resource "aws_subnet" "subnets" {
  for_each = var.subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.public # Public 서브넷만 퍼블릭 IP 자동 부여

  tags = merge(var.tags, {
    Name       = "${var.name}-${each.value.name}"
    SubnetType = each.value.type
  })
}

###############################################
# NAT Gateway (AZ별 Public Subnet에 1개씩)
# - 설계 문서: Private Subnet → NAT GW → IGW
# - 비용은 NAT 개수 × 시간 + 트래픽 기준
###############################################

# 퍼블릭 서브넷 수만큼 EIP 생성 (AZ별 NAT)
resource "aws_eip" "nat" {
  for_each = { for k, v in var.subnets : k => v if v.public }

  # vpc = true 는 요즘 deprecated 경고라 빼도 됨
  tags = merge(var.tags, {
    Name = "${var.name}-nat-eip-${each.key}"
  })
}

# 각 퍼블릭 서브넷에 NAT GW 생성
resource "aws_nat_gateway" "nat_gw" {
  for_each = aws_eip.nat

  subnet_id     = aws_subnet.subnets[each.key].id
  allocation_id = each.value.id

  tags = merge(var.tags, {
    Name = "${var.name}-nat-gw-${each.key}"
  })
}

# 편의를 위해 NAT GW 중 첫 번째를 기본으로 사용
# (원하면 나중에 AZ별 RT로 더 세분화 가능)
locals {
  first_nat_gw_id = length(aws_nat_gateway.nat_gw) > 0 ? values(aws_nat_gateway.nat_gw)[0].id : null
}

###############################################
# Route Tables
# 문서 기준:
# - Public: 0.0.0.0/0 → IGW
# - Private-App: 0.0.0.0/0 → NAT, 10.100.0.0/16 → VGW
# - Private-DB: 0.0.0.0/0 없음, IDC 선택적
# - Private-Infra: 0.0.0.0/0 → NAT, 10.100.0.0/16 → VGW
###############################################

########## Public Route Table ##########
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-rt-public"
  })
}

# 0.0.0.0/0 → IGW
resource "aws_route" "public_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Public Subnet 모두 Public RT에 연결
resource "aws_route_table_association" "public_assoc" {
  for_each = { for k, v in var.subnets : k => v if v.public }

  subnet_id      = aws_subnet.subnets[each.key].id
  route_table_id = aws_route_table.public.id
}

########## Private-App Route Table ##########
resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-rt-private-app"
  })
}

# 0.0.0.0/0 → NAT GW
resource "aws_route" "private_app_nat" {
  route_table_id         = aws_route_table.private_app.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = local.first_nat_gw_id
}

# 10.100.0.0/16 → VGW (IDC 연동, enable_idc=true일 때만)
resource "aws_route" "private_app_idc" {
  count = var.enable_idc && var.vgw_id != null ? 1 : 0

  route_table_id         = aws_route_table.private_app.id
  destination_cidr_block = var.idc_cidr
  gateway_id             = var.vgw_id
}

# Private-App Subnet 모두 Private-App RT에 연결
resource "aws_route_table_association" "private_app_assoc" {
  for_each = { for k, v in var.subnets : k => v if v.type == "private-app" }

  subnet_id      = aws_subnet.subnets[each.key].id
  route_table_id = aws_route_table.private_app.id
}

########## Private-DB Route Table ##########
resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-rt-private-db"
  })
}

# DB 서브넷은 기본적으로 인터넷 경로 없음
# 필요하면 IDC로만 경로를 연다.
resource "aws_route" "private_db_idc" {
  count = var.enable_db_idc && var.vgw_id != null ? 1 : 0

  route_table_id         = aws_route_table.private_db.id
  destination_cidr_block = var.idc_cidr
  gateway_id             = var.vgw_id
}

# Private-DB Subnet 모두 Private-DB RT에 연결
resource "aws_route_table_association" "private_db_assoc" {
  for_each = { for k, v in var.subnets : k => v if v.type == "private-db" }

  subnet_id      = aws_subnet.subnets[each.key].id
  route_table_id = aws_route_table.private_db.id
}

########## Private-Infra Route Table ##########
resource "aws_route_table" "private_infra" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-rt-private-infra"
  })
}

# 0.0.0.0/0 → NAT GW (외부 SaaS, 모니터링 등)
resource "aws_route" "private_infra_nat" {
  route_table_id         = aws_route_table.private_infra.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = local.first_nat_gw_id
}

# 10.100.0.0/16 → VGW (IDC 이벤트 수신/송신용)
resource "aws_route" "private_infra_idc" {
  count = var.enable_idc && var.vgw_id != null ? 1 : 0

  route_table_id         = aws_route_table.private_infra.id
  destination_cidr_block = var.idc_cidr
  gateway_id             = var.vgw_id
}

# Private-Infra Subnet 모두 Private-Infra RT에 연결
resource "aws_route_table_association" "private_infra_assoc" {
  for_each = { for k, v in var.subnets : k => v if v.type == "private-infra" }

  subnet_id      = aws_subnet.subnets[each.key].id
  route_table_id = aws_route_table.private_infra.id
}
