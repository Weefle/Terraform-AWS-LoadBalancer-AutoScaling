variable "region" {
type = string
default = "us-east-1" # La valeur par défaut est définie sur us-east-1, mais peut être remplacée lors de l'exécution de la configuration Terraform.
}

variable "image_id" {
type = string
default = "ami-0557a15b87f6559cf" # La valeur par défaut est définie sur l'AMI Amazon Linux 2 pour la région us-east-1, mais peut être remplacée lors de l'exécution de la configuration Terraform.
}

variable "flavor" {
type = string
default = "t2.micro" # La valeur par défaut est définie sur une instance t2.micro, mais peut être remplacée lors de l'exécution de la configuration Terraform.
}

variable "ec2_instance_port" {
type = number
default = 80 # La valeur par défaut est définie sur le port 80, mais peut être remplacée lors de l'exécution de la configuration Terraform.
}

variable "cidr_block"{
  type = string
  description = "CIDR block to be used"
  default = "172.20.0.0/16"
}

variable "vpc_name"{
  type = string
  description = "Vpc name"
  default = "Test"
}