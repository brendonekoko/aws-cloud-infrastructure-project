terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

resource "aws_vpc" "luxury_real_estate" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "luxury-real-estate-vpc"
    Project = "LuxuryRealEstate"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.luxury_real_estate.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "luxury-public-a"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.luxury_real_estate.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name = "luxury-private-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.luxury_real_estate.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "luxury-public-b"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.luxury_real_estate.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-2b"

  tags = {
    Name = "luxury-private-b"
  }
}
resource "aws_internet_gateway" "luxury_igw" {
  vpc_id = aws_vpc.luxury_real_estate.id

  tags = {
    Name = "luxury-real-estate-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.luxury_real_estate.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.luxury_igw.id
  }

  tags = {
    Name = "luxury-public-route-table"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.luxury_real_estate.id

  tags = {
    Name = "luxury-private-route-a"
  }
}

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.luxury_real_estate.id

  tags = {
    Name = "luxury-private-route-b"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_b.id
}
resource "aws_security_group" "alb" {
  name        = "luxury-alb-sg"
  description = "Security group for the public ALB"
  vpc_id      = aws_vpc.luxury_real_estate.id

  ingress {
    description = "Allow HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "luxury-alb-sg"
  }
}

resource "aws_security_group" "ec2" {
  name        = "luxury-ec2-sg"
  description = "Security group for private EC2 servers"
  vpc_id      = aws_vpc.luxury_real_estate.id

  ingress {
    description     = "Allow HTTP only from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "luxury-ec2-sg"
  }
}
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "luxury-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "luxury-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_launch_template" "web" {
  name_prefix   = "luxury-web-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  user_data = base64encode(<<-EOF
  #!/bin/bash
  dnf install -y httpd
  systemctl enable --now httpd

  cat > /var/www/html/index.html <<'HTML'
  <!DOCTYPE html>
  <html>
  <head><title>Luxury Real Estate</title></head>
  <body>
    <h1>Welcome to Luxury Real Estate</h1>
    <p>Explore our exclusive luxury properties.</p>
  </body>
  </html>
  HTML
EOF
  )

  vpc_security_group_ids = [
    aws_security_group.ec2.id
  ]

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2.arn
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name    = "luxury-web-server"
      Project = "LuxuryRealEstate"
    }
  }
}
resource "aws_eip" "nat_a" {
  domain = "vpc"

  tags = {
    Name = "luxury-nat-eip-a"
  }
}

resource "aws_eip" "nat_b" {
  domain = "vpc"

  tags = {
    Name = "luxury-nat-eip-b"
  }
}

resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public_a.id

  depends_on = [aws_internet_gateway.luxury_igw]

  tags = {
    Name = "luxury-nat-a"
  }
}

resource "aws_nat_gateway" "nat_b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.public_b.id

  depends_on = [aws_internet_gateway.luxury_igw]

  tags = {
    Name = "luxury-nat-b"
  }
}

resource "aws_route" "private_nat_a" {
  route_table_id         = aws_route_table.private_a.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_a.id
}

resource "aws_route" "private_nat_b" {
  route_table_id         = aws_route_table.private_b.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_b.id
}

resource "aws_lb" "luxury_alb" {
  name               = "luxury-real-estate-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  tags = {
    Name = "luxury-real-estate-alb"
  }
}

resource "aws_lb_target_group" "web" {
  name     = "luxury-web-targets"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.luxury_real_estate.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "luxury-web-targets"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.luxury_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
resource "aws_autoscaling_group" "web" {
  name             = "luxury-web-asg"
  min_size         = 2
  max_size         = 4
  desired_capacity = 3
  vpc_zone_identifier = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  target_group_arns = [
    aws_lb_target_group.web.arn
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "luxury-web-server"
    propagate_at_launch = true
  }
}
data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "website_s3_read" {
  name = "luxury-website-s3-read"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "arn:aws:s3:::yvettes-realty-${data.aws_caller_identity.current.account_id}-us-east-2/website/*"
        ]
      }
    ]
  })
}
