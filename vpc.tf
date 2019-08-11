provider "aws" {
    region = "${var.region}"
}

resource "aws_vpc" "main" {
    cidr_block = "${var.vpc_cidr}"
    instance_tenancy = "default"
    enable_dns_support  = "true"
    enable_dns_hostnames= "true"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = "${aws_eip.nateip.id}"
  subnet_id      = "${element(aws_subnet.publicsubnets.*.id, 0)}"
}

resource "aws_eip" "nateip" {
  vpc      = true
}

resource "aws_subnet" "publicsubnets" {
    #AZS and subnets from data source
    count = "3" # ${length(data.aws_availability_zones.azs.names)}"
    vpc_id     = "${aws_vpc.main.id}"
    availability_zone = "${element(data.aws_availability_zones.azs.names,count.index)}"
    cidr_block = "${element(var.subnet_cidr_public,count.index)}"

    map_public_ip_on_launch = true
}

resource "aws_route_table" "publicRT" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }
}

resource "aws_route_table_association" "public" {
  count = "3" # "${length(aws_subnet.publicsubnets.*.id)}"
  subnet_id      = "${element(aws_subnet.publicsubnets.*.id, count.index)}"
  route_table_id = "${aws_route_table.publicRT.id}"
}

resource "aws_subnet" "privatesubnets" {
    #AZS and subnets from data source
    count = "3" # ${length(data.aws_availability_zones.azs.names)}"
    vpc_id     = "${aws_vpc.main.id}"
    availability_zone = "${element(data.aws_availability_zones.azs.names,count.index)}"
    cidr_block = "${element(var.subnet_cidr_private,count.index)}"

    map_public_ip_on_launch = false
}

resource "aws_route_table" "privateRT" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.natgw.id}"
  }
}

resource "aws_route_table_association" "private" {
  count = "3" # ${length(aws_subnet.privatesubnets.*.id)}"
  subnet_id      = "${element(aws_subnet.privatesubnets.*.id, count.index)}"
  route_table_id = "${aws_route_table.privateRT.id}"
}

output "vpc_id" {
  value = "${aws_vpc.main.id}"
}

output "public_subnet_id" {
  value = "${join(",", aws_subnet.publicsubnets.*.id)}"
}

output "private_subnet_id" {
  value = "${join(",", aws_subnet.privatesubnets.*.id)}"
}
