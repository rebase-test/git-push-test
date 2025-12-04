# 리소스 네이밍 prefix (예: ddos-seoul)
variable "name" {
  description = "리소스 이름 prefix"
  type        = string
}

# VPC CIDR (/16, 예: 10.10.0.0/16)
variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}

# 서브넷 정의
# - cidr   : 각 서브넷 CIDR (/24)
# - az     : 가용 영역 (ap-northeast-2a / 2c)
# - type   : public / private-app / private-db / private-infra
# - name   : 콘솔에 표시할 이름 suffix
# - public : 퍼블릭 여부 (IGW 연결 여부)
variable "subnets" {
  description = "서브넷 정의 맵"
  type = map(object({
    cidr   = string
    az     = string
    type   = string
    name   = string
    public = bool
  }))
}

# 공통 태그
variable "tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}

# IDC 연동 사용 여부 (Private-App, Private-Infra에서 VGW로 라우팅 추가할지 여부)
variable "enable_idc" {
  description = "IDC 연동 사용 여부 (App, Infra 서브넷)"
  type        = bool
  default     = false
}

# DB 서브넷도 IDC와 연동할지 여부 (기본값 false)
variable "enable_db_idc" {
  description = "DB 서브넷에서 IDC 연동 사용 여부"
  type        = bool
  default     = false
}

# IDC 온프렘 CIDR (예: 10.100.0.0/16)
variable "idc_cidr" {
  description = "IDC 온프렘 CIDR"
  type        = string
  default     = "10.100.0.0/16"
}

# VGW 또는 TGW ID (실제 IDC 연결 시 외부에서 주입)
# 아직 IDC를 안 만든 상태라면 null로 두고 enable_*_idc = false 상태로 사용
variable "vgw_id" {
  description = "IDC 연동용 VGW/TGW ID (옵션)"
  type        = string
  default     = null
}
