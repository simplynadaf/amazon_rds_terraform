provider "aws" {
  region = "us-west-2"  # Specify your AWS region
}

# Reference the existing VPC using a variable
data "aws_vpc" "existing_vpc" {
  id = var.vpc_id
}

# Reference the existing Security Group using a variable
data "aws_security_group" "existing_sg" {
  id = var.security_group_id
}

# Reference the existing subnets in the VPC
data "aws_subnet_ids" "existing_subnets" {
  vpc_id = data.aws_vpc.existing_vpc.id
}

# Create a DB subnet group using the existing subnets
resource "aws_db_subnet_group" "aurora_subnet_group" {
  name       = "aurora_existing_subnet_group"
  subnet_ids = data.aws_subnet_ids.existing_subnets.ids

  tags = {
    Name = "Aurora Subnet Group"
  }
}

# Store the DB password in Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name        = "aurora-db-password"
  description = "Aurora PostgreSQL DB password"
}

# Store the secret value (the actual password)
resource "aws_secretsmanager_secret_version" "db_password_value" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    password = var.db_password  # Retrieve the password from the Terraform variable
  })
}

# Aurora PostgreSQL cluster (no replicas, single instance, no backups)
resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier      = "aurora-postgres-cluster"
  engine                  = "aurora-postgresql"
  engine_version          = "13.6"  # Use the latest Aurora PostgreSQL version
  database_name           = "glue_database"  # Database name as requested
  master_username         = "admin"
  
  # Retrieve the password from Secrets Manager
  master_password         = jsondecode(aws_secretsmanager_secret_version.db_password_value.secret_string)["password"]

  # Networking configurations
  vpc_security_group_ids  = [data.aws_security_group.existing_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.aurora_subnet_group.id

  # Disable backups by setting retention period to 0
  backup_retention_period = 0  # No backups
  preferred_backup_window = "" # Since no backups, no window is needed
  preferred_maintenance_window = "Mon:00:00-Mon:03:00"

  storage_encrypted       = true
  apply_immediately       = true

  tags = {
    Name = "Glue Database Connection test"
  }
}

# Create a single Aurora instance (no replicas)
resource "aws_rds_cluster_instance" "aurora_instance" {
  identifier              = "aurora-postgres-instance"
  cluster_identifier      = aws_rds_cluster.aurora_cluster.id
  instance_class          = "db.r6g.large"  # Choose the instance type that suits your needs
  engine                  = aws_rds_cluster.aurora_cluster.engine
  engine_version          = aws_rds_cluster.aurora_cluster.engine_version

  publicly_accessible     = false  # Ensuring the instance is not publicly accessible
  apply_immediately       = true

  tags = {
    Name = "Glue Database Connection test"
  }
}

# Output the Aurora endpoint
output "aurora_endpoint" {
  value = aws_rds_cluster.aurora_cluster.endpoint
}

# Output the Aurora instance identifier
output "aurora_instance_id" {
  value = aws_rds_cluster_instance.aurora_instance.id
}
