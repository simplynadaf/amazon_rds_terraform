# variables.tf

variable "vpc_id" {
  description = "The ID of the existing VPC"
  type        = string
}

variable "security_group_id" {
  description = "The ID of the existing Security Group"
  type        = string
}

variable "db_password" {
  description = "Password for the Aurora DB"
  type        = string
  sensitive   = true  # Marking this as sensitive to avoid it being shown in the Terraform output
}
