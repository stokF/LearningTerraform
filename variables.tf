variable "instance_type" {
  description = "Type of EC2 instance to provision"
  default     = "t3.micro"
}

variable "ami_filter" {
  description = "Name filter and owner for AMI"
  type = object ({
    name  = string
    owner = string
  })

  default = {
    name   = "al2023-ami-2023*-x86_64"
    owner = "amazon" # Amazon Linux 2023
  }
}

variable "environment" {
  description = "Deployment environment"
  tpye = object ({
    name = string
    network_prefix = string
  })
  default = {
    name           = "dev"
    network_prefix = "10.0"
  }
}

variable  "min_size" {
  description = "Minimum number of instances in the ASG"
  default = 1 
} 
variable  "max_size" {
  description = "Maximum number of instances in the ASG"
  default = 2     \
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

resource "aws_lb_target_group" "blog" {
  name     = "blog"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.blog_vpc.vpc_id
}
