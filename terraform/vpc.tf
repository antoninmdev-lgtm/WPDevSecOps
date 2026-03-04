resource "aws_vpc" "wp_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "devsecops-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.wp_vpc.id
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.wp_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.wp_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.wp_vpc.id
}

resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  name              = "/aws/vpc-flow-log/${aws_vpc.wp_vpc.id}"
  retention_in_days = 7
  #checkov:skip=CKV_AWS_338
  #checkov:skip=CKV_AWS_158
}

resource "aws_flow_log" "vpc_flow_log" {
  iam_role_arn      = var.iam_role_arn
  log_destination   = aws_cloudwatch_log_group.vpc_flow_log.arn
  traffic_type      = "ALL"
  vpc_id            = aws_vpc.wp_vpc.id
}
