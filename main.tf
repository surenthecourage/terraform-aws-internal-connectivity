# Project VPC
resource "aws_vpc" "project_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Public Subnet
resource "aws_subnet" "public_subnet" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.project_vpc.id
  cidr_block              = element(var.public_subnet_cidrs, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

# Private Subnet
resource "aws_subnet" "private_subnet" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.project_vpc.id
  cidr_block        = element(var.private_subnet_cidrs, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name = "${var.project_name}-private-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "project_igw" {
  vpc_id = aws_vpc.project_vpc.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "project_nat" {
  allocation_id = aws_eip.nat_gw_eip.id
  subnet_id     = element(aws_subnet.public_subnet.*.id, 0)

  tags = {
    Name = "${var.project_name}-nat"
  }
}

# Public IP for Nat Gateway
resource "aws_eip" "nat_gw_eip" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-eip"
  }
}

# Route table - Public
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.project_vpc.id

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Public Route
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.project_igw.id
}

# Public Route table association
resource "aws_route_table_association" "public_rta" {
  count = length(var.public_subnet_cidrs)

  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
}

# Route table - Private
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.project_vpc.id

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# Private Route
resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.project_nat.id
}

# Private Route table association
resource "aws_route_table_association" "private_rta" {
  count = length(var.private_subnet_cidrs)

  route_table_id = aws_route_table.private_route_table.id
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
}

# Security Groups for private subnet instances
resource "aws_security_group" "project_main_sg" {
  name   = "Security Groups for private subnet instances"
  vpc_id = aws_vpc.project_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-security-group"
  }
}

# AWS key pair
resource "aws_key_pair" "project_ssh_key" {
  key_name   = "ssh_key"
  public_key = file(var.public_key_path)

  tags = {
    Name = "ssh-key"
  }
}

# EC2 instances located in private subnet
resource "aws_instance" "project_instance" {
  count         = length(var.instances)
  instance_type = var.instances[count.index].instance_type
  ami           = var.instances[count.index].ami_id
  key_name      = aws_key_pair.project_ssh_key.key_name

  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.project_main_sg.id]

  # Assign a subnet based on count index
  subnet_id = aws_subnet.private_subnet[count.index % length(var.private_subnet_cidrs)].id

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = var.instances[count.index].tags
}

# jump_server configuration

# jump_server security Group
resource "aws_security_group" "jump_server_sg" {
  vpc_id = aws_vpc.project_vpc.id
  name   = "jump_server Security Group"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-jump_server-sg"
  }
}

# jump_server host EC2 instance
resource "aws_instance" "jump_server" {
  ami                         = "ami-04a81a99f5ec58529"
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.project_ssh_key.key_name
  associate_public_ip_address = false
  subnet_id                   = element(aws_subnet.private_subnet.*.id, 0)

  vpc_security_group_ids = [aws_security_group.jump_server_sg.id]

  tags = {
    Name = "${var.project_name}-jump_server"
  }
}

# Network Load Balancer - SG
resource "aws_security_group" "nlb_sg" {
  vpc_id = aws_vpc.project_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Network Load Balancer
resource "aws_lb" "nlb" {
  name               = "vpc-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = [aws_subnet.private_subnet[0].id]

  enable_deletion_protection = false
}

# Network Load Balancer Target Groups
resource "aws_lb_target_group" "tg" {
  name     = "tg"
  port     = 22
  protocol = "TCP"
  vpc_id   = aws_vpc.project_vpc.id

  health_check {
    interval            = 30
    protocol            = "TCP"
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
  depends_on = [aws_lb.nlb]
}

# Network Load Balancer Listener
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 22
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# Network Load Balancer Target Group Attachment
resource "aws_lb_target_group_attachment" "tga" {
  count            = length(aws_instance.jump_server.*.id)
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = element(aws_instance.jump_server.*.id, count.index)
  port             = 22
}

# VPC Endpoint
resource "aws_vpc_endpoint_service" "endpoint_service" {
  acceptance_required        = true
  network_load_balancer_arns = [aws_lb.nlb.arn]
}

# output "nlb_dns_name" {
#   value = aws_lb.nlb.dns_name
# }