provider "aws" {
  region = "ap-northeast-2"
}

variable "key_name" {
  description = "EC2 Key Pair Name"
  type        = string
  default     = "WHSkey"
}

# VPC 및 네트워크
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "WHS-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "WHS-igw" }
}

resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/20"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true
  tags                    = { Name = "public1" }
}

resource "aws_subnet" "private1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.128.0/20"
  availability_zone = "ap-northeast-2a"
  tags              = { Name = "private1" }
}

resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.144.0/20"
  availability_zone = "ap-northeast-2a"
  tags              = { Name = "private2" }
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public1.id
  tags          = { Name = "WHS-natgw" }
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "WHS-rtb-public" }
}

resource "aws_route_table" "private1" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }
  tags = { Name = "WHS-rtb-private1" }
}

resource "aws_route_table" "private2" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }
  tags = { Name = "WHS-rtb-private2" }
}

resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private1.id
}
resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private2.id
}

# 보안 그룹
resource "aws_security_group" "sg_bastion" {
  name        = "SG-bastion"
  vpc_id      = aws_vpc.main.id
  description = "Bastion host SG"
  ingress {
    from_port   = 22
    to_port     = 22
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

resource "aws_security_group" "sg_web_public" {
  name        = "SG-web-public"
  vpc_id      = aws_vpc.main.id
  description = "Public web SG"
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
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_bastion.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sg_web_private" {
  name        = "SG-web-private"
  vpc_id      = aws_vpc.main.id
  description = "Private web SG"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  ingress {
    from_port   = 8084
    to_port     = 8084
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.26/32"]
  }
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_bastion.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sg_db_1" {
  name        = "SG-db-1"
  vpc_id      = aws_vpc.main.id
  description = "DB1 SG"
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_web_public.id] # Public Web만 허용
  }
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_bastion.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sg_db_2" {
  name        = "SG-db-2"
  vpc_id      = aws_vpc.main.id
  description = "DB2 SG"
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_web_private.id] # Private Web만 허용
  }
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_bastion.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sg_wazuh_server" {
  name        = "wazuh-server"
  vpc_id      = aws_vpc.main.id
  description = "Wazuh server SG"
  ingress {
    from_port   = 1514
    to_port     = 1516
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  ingress {
    from_port   = 1514
    to_port     = 1516
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  ingress {
    from_port   = 514
    to_port     = 514
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  ingress {
    from_port   = 514
    to_port     = 514
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  ingress {
    from_port   = 8083
    to_port     = 8083
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_bastion.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 인스턴스 및 EIP
resource "aws_instance" "public_web" {
  ami                    = "ami-0eb3d908ec1091b2f"
  instance_type          = "t2.micro"
  key_name               = var.key_name
  subnet_id              = aws_subnet.public1.id
  private_ip             = "10.0.12.95"
  vpc_security_group_ids = [aws_security_group.sg_web_public.id, aws_security_group.sg_bastion.id]
  tags                   = { Name = "public_web" }
}

resource "aws_instance" "bastion_host" {
  ami                    = "ami-00e379bbbd653e424"
  instance_type          = "t2.micro"
  key_name               = var.key_name
  subnet_id              = aws_subnet.public1.id
  private_ip             = "10.0.0.26"
  vpc_security_group_ids = [aws_security_group.sg_bastion.id]
  tags                   = { Name = "bastion_host" }
}

resource "aws_instance" "admin_web" {
  ami                    = "ami-0c38d157ded9fc429"
  instance_type          = "t2.micro"
  key_name               = var.key_name
  subnet_id              = aws_subnet.private1.id
  private_ip             = "10.0.129.144"
  vpc_security_group_ids = [aws_security_group.sg_web_private.id]
  tags                   = { Name = "admin_web" }
}

resource "aws_instance" "db_1" {
  ami                    = "ami-01b10ac4aac623d41"
  instance_type          = "t2.micro"
  key_name               = var.key_name
  subnet_id              = aws_subnet.private1.id
  private_ip             = "10.0.137.192"
  vpc_security_group_ids = [aws_security_group.sg_db_1.id]
  tags                   = { Name = "db_1" }
}

resource "aws_instance" "db_2" {
  ami                    = "ami-070d31abbe1f508e0"
  instance_type          = "t2.micro"
  key_name               = var.key_name
  subnet_id              = aws_subnet.private1.id
  private_ip             = "10.0.134.8"
  vpc_security_group_ids = [aws_security_group.sg_db_2.id]
  tags                   = { Name = "db_2" }
}

resource "aws_instance" "wazuh_server" {
  ami                    = "ami-006f0d088054aca78"
  instance_type          = "c5a.xlarge"
  key_name               = var.key_name
  subnet_id              = aws_subnet.private2.id
  private_ip             = "10.0.155.166"
  vpc_security_group_ids = [aws_security_group.sg_wazuh_server.id]
  tags                   = { Name = "wazuh_server" }
}

resource "aws_eip" "public_web" {
  instance = aws_instance.public_web.id
  domain   = "vpc"
}

resource "aws_eip" "bastion_host" {
  instance = aws_instance.bastion_host.id
  domain   = "vpc"
}

output "public_web_eip" {
  value = aws_eip.public_web.public_ip
}
output "bastion_eip" {
  value = aws_eip.bastion_host.public_ip
}
output "wazuh_server_private_ip" {
  value = aws_instance.wazuh_server.private_ip
}