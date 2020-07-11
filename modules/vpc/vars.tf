variable "region" {
    default = "us-east-1"
}

variable "vpc_cidr" {
    default = "192.160.0.0/16"
}

variable "subnet_cidr_public" {
    type    = "list"
    default = ["192.160.1.0/24","192.160.2.0/24","192.160.3.0/24"]
}

variable "subnet_cidr_private" {
    type    = "list"
    default = ["192.160.4.0/24","192.160.5.0/24","192.160.6.0/24"]
}


variable "azs" {
    type    = "list"
    default = ["us-east-1a","us-east-1b","us-east-1c"]
}

# Declare the data source for AZS
data "aws_availability_zones" "azs" {}
