variable "project" {
  type    = string
  default = "jada"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.100.0.0/16"
}

variable "public_cidr" {
  type    = string
  default = "10.100.1.0/24"
}

variable "admin_cidr" {
  type        = string
  description = "Your IP/32 for SSH access to the VM"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "ssh_public_key" {
  type        = string
  description = "Your SSH public key contents"
}