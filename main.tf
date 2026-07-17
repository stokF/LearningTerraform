data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.ami_filter.name]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [var.ami_filter.owner]
}

module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.environment.name
  cidr = "${var.environment.network_prefix}.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets  = ["${var.environment.network_prefix}.101.0/24", "${var.environment.network_prefix}.102.0/24", "${var.environment.network_prefix}.103.0/24"]

  map_public_ip_on_launch = true

  tags = {
    Terraform = "true"
    Environment = var.environment.name
  }
}

module "blog_autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 9.0"

  name = "blog"

  min_size            = var.asg_min
  max_size            = var.asg_max
  vpc_zone_identifier = module.blog_vpc.public_subnets
  security_groups     = [module.blog_sg.security_group_id]

  traffic_source_attachments = {
    blog-alb = {
      traffic_source_identifier = aws_lb_target_group.blog.arn
      traffic_source_type       = "elbv2"
    }
  }

  instance_type = var.instance_type
  image_id      = data.aws_ami.app_ami.id

  user_data = base64encode(<<-USERDATA
  #!/bin/bash
  dnf install -y java-17-amazon-corretto-headless
  curl -fsSL https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.87/bin/apache-tomcat-9.0.87.tar.gz -o /opt/tomcat.tar.gz
  mkdir -p /opt/tomcat
  tar xzf /opt/tomcat.tar.gz -C /opt/tomcat --strip-components=1
  sed -i 's/port="8080"/port="80"/' /opt/tomcat/conf/server.xml
  /opt/tomcat/bin/startup.sh
  USERDATA
  )
}

module "blog_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.13.0"

  vpc_id  = module.blog_vpc.vpc_id
  name    = "blog"
  ingress_rules = ["https-443-tcp","http-80-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}

module "blog_alb" {
  source = "terraform-aws-modules/alb/aws"

  name    = "blog-alb"
  vpc_id  = module.blog_vpc.vpc_id
  subnets = module.blog_vpc.public_subnets

  security_groups = [module.blog_sg.security_group_id]

  listeners = {
    blog-http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_arn = aws_lb_target_group.blog.arn
      }
    }
  }

  tags = {
    Environment = var.environment.name
  }
}

resource "aws_lb_target_group" "blog" {
  name     = "blog"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.blog_vpc.vpc_id
}
