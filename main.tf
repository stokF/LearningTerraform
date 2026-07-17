data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"] # Amazon Linux 2023
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.app_ami.id
  instance_type = var.instance_type

  vpc_security_group_ids = [module.web_sg.security_group_id]

  tags   = {
    Name = "LearningTerraform"
  }
}

module "web_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "6.0.0"
  name    = "web_new"

  vpc_id  = data.aws_vpc.default.id

  ingress_rules = ["http-80-tcp", "https-443-tcp"]
  ingress_rule = ["0.0.0.0/0"]

  egress_rules = ["all-all"]
  egress_rule = ["0.0.0.0/0"]
}

resource "aws_security_group" "web" {
  name        = "web"
  description = "Allow http and https in. Allow everything out."

  vpc_id      = data.aws_vpc.default.id
}

resource "aws_security_group_rule" "web_http_in" {
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.web.id
}

resource "aws_security_group_rule" "web_https_in" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.web.id
}

resource "aws_security_group_rule" "web_everything_out" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.web.id
}
