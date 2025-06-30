data "aws_availability_zones" "available" {}

data "aws_ami" "amzn-linux-2023-ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

locals {
    name = "yusuf"
    vpc_cidr = "10.0.0.0/16"
    azs = slice(data.aws_availability_zones.available.names, 0, 3)
    tags = {
      Terraform = "true"
      Environment = "yusuf"
    }
}

variable "rds_password" {
  type = string
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${local.name}-vpc"
  cidr = local.vpc_cidr
  create_database_subnet_group = true

  azs             = local.azs
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnets = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false


  tags = local.tags
}

module "backend_server_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name = "${local.name}-backend-server-sg"
  description = "Security Group for backend-server that allows inbound traffic to port 22, 80, 443, and 8080"
  vpc_id = module.vpc.vpc_id

  tags = local.tags

  ingress_with_cidr_blocks = [
    {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  ingress_with_source_security_group_id = [
    {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      source_security_group_id = module.alb.security_group_id
    },
    {
      from_port = 8080
      to_port = 8080
      protocol = "tcp"
      source_security_group_id = module.alb.security_group_id
    },
  ]

  egress_with_cidr_blocks = [
    {
      from_port = 0
      to_port = 35565
      protocol = "tcp"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

module "rds_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name = "${local.name}-rds-sg"
  description = "Security Group for database that allows inbound traffic to port 5432"
  vpc_id = module.vpc.vpc_id

  tags = local.tags

  ingress_with_source_security_group_id = [
    {
      from_port = 5432
      to_port = 5432
      protocol = "tcp"
      source_security_group_id = module.backend_server_sg.security_group_id
    },
  ]
}

module "backend_server_ec2" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.8.0"

  name = "${local.name}-backend-server"

  ami                    = data.aws_ami.amzn-linux-2023-ami.id
  instance_type          = "t2.micro"
  key_name               = "yusuf-mac-key-pair"
  monitoring             = false
  vpc_security_group_ids = [module.backend_server_sg.security_group_id]
  subnet_id              = element(module.vpc.public_subnets, 0)
  associate_public_ip_address = true

  tags = local.tags
}

module "rds" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "${local.name}-db"

  engine            = "postgres"
  engine_version    = "17.4"
  major_engine_version = "17"
  family = "postgres17"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = "foodsdb"
  username = "postgres"
  password = var.rds_password
  port     = 5432

  iam_database_authentication_enabled = false

  create_monitoring_role = false

  multi_az = false
  db_subnet_group_name = module.vpc.database_subnet_group
  vpc_security_group_ids = [module.rds_sg.security_group_id]

  skip_final_snapshot = true

  tags = local.tags
}

module "alb" {
  source = "terraform-aws-modules/alb/aws"

  name    = "${local.name}-alb"
  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "HTTP web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
    all_https = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      description = "HTTPS web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "10.0.0.0/16"
    }
  }

  listeners = {
    http = {
      port            = 80
      protocol        = "HTTP"
      # certificate_arn = "arn:aws:iam::123456789012:server-certificate/test_cert-123456789012"

      forward = {
        target_group_key = "backend_server_ec2"
      }
    }
  }

  target_groups = {
    backend_server_ec2 = {
      protocol         = "HTTP"
      port             = 80
      target_type      = "instance"
      target_id        = module.backend_server_ec2.id
    }
  }

  enable_deletion_protection = false

  tags = local.tags
}