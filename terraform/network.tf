# Batch 1 as code: VPC, one public subnet, internet gateway, route to the internet.

resource "aws_vpc" "cicd" {
  cidr_block           = "10.20.0.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "cicd-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.cicd.id
  cidr_block              = "10.20.0.0/28"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "cicd-subnet-public1-${var.region}a"
  }
}

resource "aws_internet_gateway" "cicd" {
  vpc_id = aws_vpc.cicd.id

  tags = {
    Name = "cicd-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.cicd.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cicd.id
  }

  tags = {
    Name = "cicd-rtb-public"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
