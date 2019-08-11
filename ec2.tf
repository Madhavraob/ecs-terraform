provider "aws" {
    region = "${var.region}"
}

resource "aws_ecs_cluster" "ecs-cluster" {
  name = "ecs-cluster"
}

resource "aws_iam_role" "ec2_role" {
  name = "ec2_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "ec2-profile" {
  name = "ec2-profile"
  role = "${aws_iam_role.ec2_role.name}"
}

resource "aws_iam_role_policy" "ec2_policy" {
  name = "ec2_policy"
  role = "${aws_iam_role.ec2_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ecs:CreateCluster", "ecs:DeregisterContainerInstance", "ecs:DiscoverPollEndpoint",
        "ecs:Poll", "ecs:RegisterContainerInstance", "ecs:StartTelemetrySession",
        "ecs:UpdateContainerInstancesState", "ecs:Submit*", "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage",
        "logs:CreateLogStream", "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_security_group" "ec2-sg" {
  name        = "allow_all"
  description = "Allow all inbound traffic"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_launch_configuration" "launch_conf" {
  name          = "web_config"
  image_id      = "ami-0fac5486e4cff37f4"
  #ami-0c09d65d2051ada93
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.ec2-sg.id}"]
  # security_groups = ["sg-0618b71dee5bfef47"]
  iam_instance_profile  = "${aws_iam_instance_profile.ec2-profile.name}"
  # iam_instance_profile  = "ecsInstanceRole"
  user_data = <<EOF
#!/bin/bash
yum update -y
echo ECS_CLUSTER=${aws_ecs_cluster.ecs-cluster.name} >> /etc/ecs/ecs.config
echo ECS_BACKEND_HOST= >> /etc/ecs/ecs.config;
EOF
}

resource "aws_autoscaling_group" "auto-scaling" {
  name                      = "auto-scaling"
  max_size                  = 1
  min_size                  = 1
  #health_check_grace_period = 300
  #health_check_type         = "ELB"
  desired_capacity          = 1
  launch_configuration      = "${aws_launch_configuration.launch_conf.name}"
  vpc_zone_identifier       = ["${split("," , var.private_subnet_id)}"]
  # vpc_zone_identifier       = ["${element(var.public_subnet_id, 0)}",
  # "${element(var.public_subnet_id, 1)}", "${element(var.public_subnet_id, 2)}"]
}

resource "aws_cloudwatch_log_group" "ecs-logs" {
  name = "ecs-logs"

  tags {
    Environment = "production"
    Application = "serviceA"
  }
}

resource "aws_ecs_task_definition" "tesk-def" {
  family                = "service"
  container_definitions = <<EOF
[
  {
    "name": "container-def",
    "image": "369888207781.dkr.ecr.us-east-1.amazonaws.com/madhavecr:latest",
    "cpu": 400,
    "memory": 400,
    "essential": true,
    "portMappings": [
      {
        "containerPort": 3000
      }
    ]
  }
]
EOF
}

resource "aws_iam_role" "ecs_service_role" {
  name = "ecs_service_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "ecs_service_policy" {
  name = "ecs_service_policy"
  role = "${aws_iam_role.ecs_service_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action":[
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer", "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:Describe*", "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:RegisterTargets", "ec2:Describe*", "ec2:AuthorizeSecurityGroupIngress"
        ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_ecs_service" "mongo" {
  name            = "mongodb"
  cluster         = "${aws_ecs_cluster.ecs-cluster.id}"
  task_definition = "${aws_ecs_task_definition.tesk-def.arn}"
  desired_count   = 1
  iam_role        = "${aws_iam_role.ecs_service_role.arn}"
  depends_on      = ["aws_iam_role_policy.ecs_service_policy"]

  load_balancer {
    target_group_arn = "${aws_lb_target_group.node_tg.arn}"
    container_name   = "container-def"
    container_port   = 3000
  }

}

resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.ec2-sg.id}"]
  subnets            = ["${split(",", var.public_subnet_id)}"]
  # security_groups    = ["${aws_security_group.lb_sg.id}"]
  # subnets            = ["${element(var.public_subnet_id, 0)}",
  # "${element(var.public_subnet_id, 1)}", "${element(var.public_subnet_id, 2)}"]
}

resource "aws_lb_target_group" "node_tg" {
  depends_on = ["aws_lb.test"]
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${var.vpc_id}"
  # vpc_id   = "vpc-92c15de8"

  health_check {
    healthy_threshold = 3
    unhealthy_threshold = 2
    timeout = 5
    interval = 10
    path = "/users/users"
    protocol  = "HTTP"
  }

}

resource "aws_lb_listener" "alb_listner" {
  load_balancer_arn = "${aws_lb.test.arn}"
  port              = "80"
  protocol          = "HTTP"
  #ssl_policy        = "ELBSecurityPolicy-2015-05"
  #certificate_arn   = "arn:aws:iam::187416307283:server-certificate/test_cert_rab3wuqwgja25ct3n4jdj2tzu4"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.node_tg.arn}"
  }
}

resource "aws_lb_listener_rule" "static" {
  listener_arn = "${aws_lb_listener.alb_listner.arn}"
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.node_tg.arn}"
  }

  condition {
    field  = "path-pattern"
    values = ["/*"]
  }
}

resource "aws_lb_listener_rule" "health_check" {
  listener_arn = "${aws_lb_listener.alb_listner.arn}"

  action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "HEALTHY"
      status_code = "200"
    }
  }

  condition {
    field  = "path-pattern"
    values = ["/health"]
  }
}
