variable "vpc_cidr" {}
variable "subnets" {}
variable "tags" {}

variable "enable_idc" {
  default = false
}
variable "enable_db_idc" {
  default = false
}
variable "idc_cidr" {
  default = "10.100.0.0/16"
}
variable "vgw_id" {
  default = null
}
