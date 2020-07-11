
module "dev_vpc"{
    source  = "../modules/vpc"
}

module "dev_ec2"{
    source      = "../modules/ec2"
    public_subnet_id   = "${module.dev_vpc.public_subnet_id}"
    private_subnet_id   = "${module.dev_vpc.private_subnet_id}"
    vpc_id     = "${module.dev_vpc.vpc_id}"
}

# output "public_dns" {
#   value = "${module.dev_ec2.public_dns}"
# }


# output "vpc_id" {
#   value = "${aws_vpc.main.id}"
# }

# output "public_subnet_id" {
#   value = "${aws_subnet.publicsubnets.*.id}"
# }

# output "private_subnet_id" {
#   value = "${aws_subnet.privatesubnets.*.id}"
# }
