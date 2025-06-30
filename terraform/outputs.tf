output "vpc_id" {
    description = "VPC ID"
    value = module.vpc.vpc_id
}

output "vpc_public_subnets" {
    description = "VPC Public Subnets"
    value = module.vpc.public_subnets
}

output "vpc_private_subnets" {
    description = "VPC Private Subnets"
    value = module.vpc.private_subnets
}

output "alb_id" {
    description = "ALB ID"
    value = module.alb.id
}

output "ec2_id" {
    description = "EC2 Instance ID"
    value = module.backend_server_ec2.id
}

output "rds_id" {
    description = "RDS Instance Identifier"
    value = module.rds.db_instance_identifier
}