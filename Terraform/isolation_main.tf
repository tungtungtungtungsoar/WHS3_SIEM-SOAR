terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
  required_version = ">= 1.0"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "forensic_snapshot_ids" {
  description = "공백으로 구분된 포렌식 스냅샷 ID 목록"
  type        = string
}

variable "forensic_ami_id" {
  description = "포렌식 인스턴스 AMI ID"
  type        = string
}

variable "forensic_instance_type" {
  description = "포렌식 인스턴스 타입"
  type        = string
}

variable "forensic_key_name" {
  description = "포렌식 인스턴스 EC2 Key Pair Name"
  type        = string
}

variable "forensic_instance_name" {
  description = "포렌식 인스턴스 Name 태그(고유, 중복 없음)"
  type        = string
}

variable "forensic_source_instance_id" {
  description = "감염 인스턴스의 ID"
  type        = string
}

variable "forensic_source_instance_name" {
  description = "감염 인스턴스의 Name"
  type        = string
}

provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "isolate" {
  cidr_block           = "10.200.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name    = "forensic-vpc"
    Purpose = "isolation"
  }
}

resource "aws_subnet" "isolate" {
  vpc_id            = aws_vpc.isolate.id
  cidr_block        = "10.200.1.0/24"
  availability_zone = "${var.aws_region}a"
  tags = {
    Name    = "forensic-subnet"
    Purpose = "isolation"
  }
}

resource "aws_security_group" "isolate" {
  name        = "forensic-sg"
  vpc_id      = aws_vpc.isolate.id
  description = "Forensic instance - ALL ingress blocked"

  # 모든 인바운드 차단
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
  snapshot_ids = split(" ", var.forensic_snapshot_ids)
  device_names = ["/dev/xvdb", "/dev/xvdc", "/dev/xvdd", "/dev/xvde", "/dev/xvdf", "/dev/xvdg", "/dev/xvdh"]
}

resource "aws_ebs_volume" "forensic_vol" {
  count             = length(local.snapshot_ids)
  availability_zone = "${var.aws_region}a"
  snapshot_id       = element(local.snapshot_ids, count.index)
  tags = {
    Name        = "${var.forensic_instance_name}-vol${count.index}"
    Purpose     = "isolation"
    Forensic    = "1"
    SourceId    = var.forensic_source_instance_id
    SourceName  = var.forensic_source_instance_name
    Created     = timestamp()
    Description = "Forensic EBS from ${var.forensic_source_instance_id}(${var.forensic_source_instance_name})"
  }
}

resource "aws_instance" "forensic" {
  ami                         = var.forensic_ami_id
  instance_type               = var.forensic_instance_type
  key_name                    = var.forensic_key_name
  subnet_id                   = aws_subnet.isolate.id
  vpc_security_group_ids      = [aws_security_group.isolate.id]
  associate_public_ip_address = false
  tags = {
    Name        = var.forensic_instance_name
    Purpose     = "isolation"
    Forensic    = "1"
    SourceId    = var.forensic_source_instance_id
    SourceName  = var.forensic_source_instance_name
    Created     = timestamp()
    Description = "Forensic instance from ${var.forensic_source_instance_id}(${var.forensic_source_instance_name})"
  }
}

resource "aws_volume_attachment" "forensic_vol_attach" {
  count        = length(aws_ebs_volume.forensic_vol)
  device_name  = local.device_names[count.index]
  volume_id    = aws_ebs_volume.forensic_vol[count.index].id
  instance_id  = aws_instance.forensic.id
  force_detach = true
}

output "forensic_instance_id" {
  value = aws_instance.forensic.id
}
output "forensic_instance_name" {
  value = aws_instance.forensic.tags["Name"]
}
output "forensic_volumes" {
  value = aws_ebs_volume.forensic_vol[*].id
}
