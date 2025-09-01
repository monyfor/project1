# -------- Latest Ubuntu 24.04 AMI --------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# -------- VPC + public subnet + IGW + route --------
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags                 = { Name = "${var.project}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags   = { Name = "${var.project}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_cidr
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project}-public-subnet" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "${var.project}-public-rt" }
}

resource "aws_route_table_association" "a_public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# -------- Security Group --------
resource "aws_security_group" "vm" {
  name   = "${var.project}-vm-sg"
  vpc_id = aws_vpc.vpc.id

  # SSH only from your IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  # HTTP/HTTPS public
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

  # Gatus (optional) public
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-vm-sg" }
}

# -------- KeyPair from your public key --------
resource "aws_key_pair" "deployer" {
  key_name   = "${var.project}-key"
  public_key = var.ssh_public_key
}

# -------- EC2 + Elastic IP --------
resource "aws_instance" "vm" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.vm.id]
  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true
  tags                        = { Name = "${var.project}-vm" }
}

resource "aws_eip" "vm" {
  instance   = aws_instance.vm.id
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
  tags       = { Name = "${var.project}-eip" }
}
