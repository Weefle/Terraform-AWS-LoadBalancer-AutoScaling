# Configure le fournisseur AWS, en utilisant la région définie dans les variables
provider "aws" {
  region = var.region  // Spécification de la région AWS à utiliser
}

#Défini le module alb
module "alb" {
  source = "./alb.tf"
}

#Défini le module asg
module "asg" {
  source = "./asg.tf"
}

# Crée une VPC avec l'adresse CIDR définie dans les variables
resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_block


  # Ajoute des tags à la ressource
  tags = {
    Name = "${var.vpc_name}=vpc"
  }
}


# Déclare une variable de type "map" contenant les noms des zones de disponibilité AWS, avec leurs numéros de sous-réseau correspondants
variable "azs" {
  type = map(string)
  description = "List of AZs to create subnet"


  # Définit les valeurs par défaut pour les zones de disponibilité
  default = {
    "a" = 0,
    "b" = 1,
    "c" = 2,
  }
}


# Crée des sous-réseaux publics pour chaque zone de disponibilité dans la VPC créée précédemment
resource "aws_subnet" "public"{
  for_each = var.azs


  # Associe le sous-réseau à la VPC créée précédemment
  vpc_id = aws_vpc.vpc.id


  # Définit l'adresse CIDR du sous-réseau en utilisant la fonction "cidrsubnet" de Terraform
  cidr_block = cidrsubnet(var.cidr_block,4,each.value)


  # Définit la zone de disponibilité pour le sous-réseau
  availability_zone = "${var.region}${each.key}"


  # Autorise l'attribution automatique d'une adresse IP publique à toute instance lancée dans le sous-réseau
  map_public_ip_on_launch = true
 
  # Ajoute des tags à la ressource
  tags = {
    Name = "${var.vpc_name}-public-${var.region}${each.key}"
  }
}


# Crée des sous-réseaux privés pour chaque zone de disponibilité dans la VPC créée précédemment
resource "aws_subnet" "private"{
  for_each = var.azs


  # Associe le sous-réseau à la VPC créée précédemment
  vpc_id = aws_vpc.vpc.id


  # Définit l'adresse CIDR du sous-réseau en utilisant la fonction "cidrsubnet" de Terraform
  cidr_block = cidrsubnet(var.cidr_block,4,15-each.value)


  # Définit la zone de disponibilité pour le sous-réseau
  availability_zone = "${var.region}${each.key}"


  # Empêche l'attribution automatique d'une adresse IP publique à toute instance lancée dans le sous-réseau
  map_public_ip_on_launch = false
 
  # Ajoute des tags à la ressource
  tags = {
    Name = "${var.vpc_name}-private-${var.region}${each.key}"
  }
}


# Cette section crée une passerelle Internet pour notre VPC
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id


  # Ajoute un tag pour identifier la passerelle Internet
  tags = {
    Name = "${var.vpc_name}-IGW"
  }
}




# Cette section récupère la dernière AMI NAT d'Amazon pour la région actuelle
data "aws_ami" "nat" {
  most_recent      = true
  owners           = ["amazon"]


  # Filtre les AMI NAT par nom
  filter {
    name   = "name"
    values = ["amzn-ami-vpc-nat-2018.03.0.2021*"]
  }
}


# Cette section définit une sortie qui expose l'ID de l'AMI NAT pour une utilisation ultérieure
output "ami_id" {
  value = data.aws_ami.nat.id
}


# Cette section crée un groupe de sécurité pour autoriser le trafic sortant TLS
resource "aws_security_group" "security_group"{
  name        = "allow_tls"
  description = "Allow TLS outbound traffic"
  vpc_id      = aws_vpc.vpc.id


  # Autorise tout le trafic sortant
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}


# Cette section crée une règle de sécurité qui autorise le trafic entrant SSH provenant de l'adresse IP spécifiée
resource "aws_security_group_rule" "security_group_rule" {
  type              = "ingress"
  from_port         = 22
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = [var.cidr_block]
  security_group_id = aws_security_group.security_group.id
}


# Cette section crée une paire de clés EC2 pour l'authentification SSH
resource "aws_key_pair" "key_pair" {
  key_name   = "deployer-key_dubois"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDjSP8CSuc4fui51CCjurvyy8IxfURUBVR44DoeoDaGKQMAJWsQHbb2YGQTAwHypJK3GNM/QO3h0R/FhahXtDgSbCwbEJsCncsgX/BW7PL3dZU7UbEuyIf3Z2JDn83jGxHwDmRSczk4l6JtW4O4SEZXqUYDzI6GVsihPEBZoY1XXC1JCi9mzYkUBHfyYrUO5zoddheFsffUT1a5FG/uimVDkmZu0iPh5iqCP2cJ7zURXaIj1OdsivOB3Q8eekQY6FVmHI7CeScWPmwEnY2ElUdbX7ck4u/UfxbEj/9Z8IntFbGjux8549ATgYB1jXlOOyTohHx7+MF/7swFKRAS13RPlN+08GvBtu9mPZxwIdOqWWGYAsYG1ksKTb4aewvOCF4Na2yaCNe7tQw4Y7SMsPHGvviJD/w7HfXFU4CZBcTJR+TaKVpuIrtMBZdDowwG1V4Fi9GX6JzcNorDWUdtveyZ2bVScP7uQTWqg96GAUWK3C9TQFTs+Hx2ZHUyKb1Dl0s= weefle@Benoit"
}


resource "aws_instance" "ec2" {
  for_each = var.azs  # crée une instance Amazon EC2 pour chaque élément dans la variable "azs"
  ami           = data.aws_ami.nat.id  # utilise l'AMI de la machine Amazon EC2 pour créer une instance
  instance_type = "t3.micro"  # type d'instance pour être créé
  key_name = aws_key_pair.key_pair.key_name  # spécifie la clé SSH pour l'instance EC2
  subnet_id = aws_subnet.public[each.key].id  # spécifie le sous-réseau dans lequel l'instance EC2 doit être créée
  security_groups = [aws_security_group.security_group.id]  # spécifie le groupe de sécurité pour l'instance EC2
  tags = {  # ajoute des tags à l'instance EC2 créée
    Name = "HelloWorld"
  }
}


resource "aws_eip" "eip_dubois" {
  for_each =  var.azs  # crée une adresse IP Elastic pour chaque élément dans la variable "azs"
  vpc      = true  # spécifie qu'il s'agit d'une adresse IP Elastic pour un VPC
}


resource "aws_eip_association" "eip_assoc" {
  for_each = var.azs  # associe chaque adresse IP Elastic à l'instance EC2 correspondante créée précédemment
  instance_id   = aws_instance.ec2[each.key].id
  allocation_id = aws_eip.eip_dubois[each.key].id
}


resource "aws_route_table" "prive" {
  for_each = var.azs  # crée une table de routage pour chaque élément dans la variable "azs"
  vpc_id = aws_vpc.vpc.id  # spécifie l'ID du VPC pour lequel la table de routage est créée
}


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id  # crée une table de routage publique pour le VPC spécifié
}


resource "aws_route" "prive" {
  for_each = var.azs  # crée une route pour chaque élément dans la variable "azs"
  route_table_id = aws_route_table.prive[each.key].id  # spécifie l'ID de la table de routage pour laquelle la route est créée
  destination_cidr_block    = "0.0.0.0/0"  # spécifie la plage d'adresses IP de destination pour laquelle la route est créée
  network_interface_id = aws_instance.ec2[each.key].primary_network_interface_id  # spécifie l'interface réseau de l'instance EC2 à utiliser pour la route
}


resource "aws_route" "public" {
  route_table_id = aws_route_table.public.id  # crée une route vers internet pour la table de routage publique
  destination_cidr_block    = "0.0.0.0/0"  # spécifie la plage d'adresses IP de destination pour laquelle la route est créée
  gateway_id = aws_internet_gateway.gw.id  # spécifie la passerelle Internet pour utiliser la route
}




# Cette ressource crée une association entre une table de routage privée et un sous-réseau privé.
resource "aws_route_table_association" "prive" {
  for_each = var.azs
  route_table_id = aws_route_table.prive[each.key].id
  subnet_id = aws_subnet.private[each.key].id
}




# Cette ressource crée une association entre une table de routage publique et un sous-réseau public.
resource "aws_route_table_association" "public" {
  for_each = var.azs
  route_table_id = aws_route_table.public.id
  subnet_id = aws_subnet.public[each.key].id
}

resource "aws_launch_configuration" "ec2_template" {
  image_id = var.image_id # ID de l'image EC2 utilisée pour cette configuration de lancement
  instance_type = var.flavor # type d'instance pour cette configuration de lancement
  user_data = <<-EOF
            # données utilisateur utilisées pour initialiser l'instance EC2
            #!/bin/bash
            sudo apt-get update
            sudo apt-get install nginx
            curl -L https://github.com/Lowess/restaurant-landingpage/archive/v1.0.0.tar.gz --output web.tar.gz
            tar xzf web.tar.gz --strip 1 -C /var/www/html
            rm -f web.tar.gz
            EOF




  security_groups = [aws_security_group.asg_sec_group.id] # groupe de sécurité à associer à cette configuration de lancement




  lifecycle {
    create_before_destroy = true # configuration pour créer une nouvelle instance avant de détruire l'ancienne
  }
}


# Récupère les informations par défaut sur la VPC AWS
data "aws_vpc" "default" {
  default = true
}