variable "project" {
  default     = "zomato"
  description = "project name"
}

variable "environment" {
  default     = "production"
  description = "project env"
}

variable "region" {
  default     = "ap-south-1"
  description = "project region"
}

variable "access_key" {
  default = "XXXXXXXXXXXX"
  description = project access key
}

variable "secret_key" {
  default = "XXXXXXXXXXXX"
  description = project secret key
}

variable "instance_ami" {
  default = "ami-0cca134ec43cf708f"
}

variable "instance_type" {
  default = "t2.micro"
}

locals {
  subnet_count = length(data.aws_availability_zones.available.names)
}

variable "vpc_cidr" {
  default = "172.16.0.0/16"
  description = cidr block to create vpc
}

locals {
  common_tags = {
    project     = var.project
    environment = var.project
  }
}

variable "private_domain" {
  default = "sreehari.local"
  description = "domain in private hosted zone"
}

variable "public_domain" {
  default = "1by2.online"
  description = "record to access wordpress website"
}
