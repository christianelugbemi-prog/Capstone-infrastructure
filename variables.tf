variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
  
  validation {
    condition     = can(regex("^(us-east-1|us-east-2|us-west-1|us-west-2)$", var.aws_region))
    error_message = "Region must be one of: us-east-1, us-east-2, us-west-1, us-west-2."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
  
  validation {
    condition     = can(regex("^t[23]\\.micro$", var.instance_type))
    error_message = "Instance type must be t2.micro or t3.micro for Free Tier."
  }
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair"
  type        = string
  default     = "capstone-key"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring for EC2"
  type        = bool
  default     = false  # Costs extra if true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "Capstone"
    Environment = "Development"
    ManagedBy   = "Terraform"
    Student     = "Cloud-DevOps"
  }
}