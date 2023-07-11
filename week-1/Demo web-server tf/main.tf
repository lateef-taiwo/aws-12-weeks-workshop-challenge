terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-west-2"
}

# Create a Key pair

resource "aws_key_pair" "abdul-aws-key-pair" {
  key_name   = "abdul-aws-key-pair"
  public_key = tls_private_key.rsa.public_key_openssh
}

# RSA key of size 4096 bits
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create a local file
resource "local_file" "abdul-aws-key-pair" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "abdul-aws-key-pair"
}

# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon-linux-2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}


# Define the security group for the EC2 Instance
resource "aws_security_group" "aws-sg-webserver" {
  name        = "aws-sg-webserver"
  description = "Allow incoming connections"
  vpc_id      = aws_default_vpc.default.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow incoming HTTP connections"
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow incoming SSH connections (Linux)"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Webserver-sg"
  }
}
resource "aws_default_vpc" "default" {

}

/*
resource "aws_instance" "vm-server" {
  ami                    = data.aws_ami.amazon-linux-2.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.aws-sg-webserver.id]
  key_name               = aws_key_pair.abdul-aws-key-pair.key_name
  user_data              = file("userdata.tpl")

  tags = {
    Name = "aws-webserver-demo"
  }
}
*/

resource "aws_launch_template" "aws-launch-template" {
  name                   = "aws-launch-template"
  image_id               = data.aws_ami.amazon-linux-2.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.abdul-aws-key-pair.key_name
  vpc_security_group_ids = [aws_security_group.aws-sg-webserver.id]
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "aws-webserver-demo"
    }
  }
  user_data = filebase64("userdata.tpl")
}

resource "aws_autoscaling_group" "aws-autoscaling-group" {
  availability_zones = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
  desired_capacity   = 2
  max_size           = 3
  min_size           = 2

  launch_template {
    id      = aws_launch_template.aws-launch-template.id
    version = "$Latest"
  }
}
