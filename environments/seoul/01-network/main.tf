terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ⚠ profile 안 쓰고 default 자격증명 사용
#   (credentials 파일의 [default]를 수정해 사용 중이니까)
provider "aws" {
  region = "ap-northeast-2"
}

module "network" {
  source = "../../../modules/network"

  name     = "ddos-seoul"
  vpc_cidr = var.vpc_cidr
  subnets  = var.subnets
  tags     = var.tags

  enable_idc    = var.enable_idc
  enable_db_idc = var.enable_db_idc
  idc_cidr      = var.idc_cidr
  vgw_id        = var.vgw_id
}

# 편의용 출력
output "vpc_id" {
  value = module.network.vpc_id
}

output "subnet_ids" {
  value = module.network.subnet_ids
}
