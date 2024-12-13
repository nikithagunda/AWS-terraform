provider "aws" {
  region = "us-west-2"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Public Subnet in AZ us-west-2a
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = true
}

# Private Subnet A in AZ us-west-2a
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-west-2a"
}

# Private Subnet B in AZ us-west-2b
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-west-2b"
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Public Route Table Association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  vpc = true
}

# NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

# Private Route Table Association for Private Subnet A
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

# Private Route Table Association for Private Subnet B
resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# KMS Key
resource "aws_kms_key" "cmk" {
  description = "CMK for encrypting resources"
}

# EC2 Instance in Private Subnet A
resource "aws_instance" "private" {
  ami           = "ami-0075013580f6322a1" 
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_a.id

  root_block_device {
    volume_size = 8
    encrypted   = true
    kms_key_id  = aws_kms_key.cmk.arn
  }

  tags = {
    Name = "Private EC2 Instance"
  }
}

# RDS Instance
resource "aws_db_instance" "default" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.m5.large"
  identifier           = "mydb"
  username             = "admin"
  password             = "password"  # Use a secure method to manage secrets
  db_subnet_group_name = aws_db_subnet_group.default.name
  multi_az             = false
  publicly_accessible  = false
  storage_encrypted    = true
  kms_key_id           = aws_kms_key.cmk.arn

  tags = {
    Name = "RDS Instance"
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = {
    Name = "Main DB Subnet Group"
  }
}
