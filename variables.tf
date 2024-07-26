variable "region" {
  default = "us-east-1"
  type    = string
}

variable "instances" {
  type = list(object({
    instance_type = string
    ami_id        = string
    tags          = map(string)
  }))
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR block for the public subnet"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR block for the private subnet"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of availability zones."
  type        = list(string)
}

variable "public_key_path" {
  description = "Path to Public Key"
  type        = string
}

variable "project_name" {
  description = "The project name for tagging resources"
  default     = "project"
}