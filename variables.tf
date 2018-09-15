variable "access_key" {}
variable "secret_key" {}
variable "key_file" {}
variable "key_name" {}
variable "vpc_subnet_id" {}
variable "vpc_id" {}
variable "tag_owner" {}
variable "hosted_zoneid" {}
variable "domain_name" {}
variable "count_instances" {}

variable "vpc_subnets" {
  default = ["subnet-123", "subnet-456", "subnet-789"]
}

variable "zones" {
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "tag_app" {
  default = "mongodb"
}

variable "tag_env" {
  default = "development"
}

variable "region" {
  default = "us-east-1"
}

variable "instance_types" {
  default = {
    mongodb = "t2.small"
  }
}

variable "os_versions" {
  default = {
    default = "centos-7"
  }
}

variable "security_group" {
  default = "mongodb-group"
}

variable "amis" {
  # for us-east-1 region
  default = {
    centos-7 = "ami-9887c6e7" # CentOS Linux 7 x86_64 HVM EBS ENA 1805_01
  }
}

variable "users" {
  default = {
    ami-9887c6e7 = "centos"
  }
}
