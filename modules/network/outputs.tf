###############################################
# VPC ID
###############################################
output "vpc_id" {
  value = aws_vpc.this.id
}

###############################################
# 서브넷 타입별 ID 맵
###############################################
output "public_subnets" {
  value = { for k, s in aws_subnet.subnets : k => s.id if var.subnets[k].public }
}

output "private_app_subnets" {
  value = { for k, s in aws_subnet.subnets : k => s.id if var.subnets[k].type == "private-app" }
}

output "private_db_subnets" {
  value = { for k, s in aws_subnet.subnets : k => s.id if var.subnets[k].type == "private-db" }
}

output "private_infra_subnets" {
  value = { for k, s in aws_subnet.subnets : k => s.id if var.subnets[k].type == "private-infra" }
}

# 모든 서브넷 ID를 한 번에 반환 (검증/테스트용)
output "subnet_ids" {
  value = { for k, s in aws_subnet.subnets : k => s.id }
}
