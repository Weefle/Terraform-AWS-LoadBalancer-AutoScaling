resource "aws_security_group" "asg_sec_group" {
  name = "asg_sec_group" # nom du groupe de sécurité
  description = "Security Group for the ASG" # description du groupe de sécurité
  tags = {
    name = "name" # étiquette pour le groupe de sécurité
  }
 
  egress {
    from_port = 0 # numéro de port source pour la règle sortante
    protocol = "-1" # protocole pour la règle sortante (tous les protocoles)
    to_port = 0 # numéro de port de destination pour la règle sortante
    cidr_blocks = ["0.0.0.0/0"] # blocs CIDR pour lesquels cette règle sortante s'applique
  }
 
  ingress {
    from_port = 80 # numéro de port source pour la règle entrante
    protocol = "tcp" # protocole pour la règle entrante (TCP)
    to_port = 80 # numéro de port de destination pour la règle entrante
    security_groups = [aws_security_group.alb-sec-group.id] # groupes de sécurité autorisés pour cette règle entrante
  }
}

# Crée un groupe d'auto-scaling pour gérer la capacité des instances EC2
resource "aws_autoscaling_group" "Practice_ASG" {
  max_size = 5  # Nombre maximum d'instances EC2 dans le groupe
  min_size = 2  # Nombre minimum d'instances EC2 dans le groupe
  launch_configuration = aws_launch_configuration.ec2_template.name  # Utilise le template EC2 à lancer
  health_check_grace_period = 300 # Période de grâce de 5 minutes pour la vérification de l'état de santé
  health_check_type = "ELB" # Utilise Elastic Load Balancer pour vérifier l'état de santé des instances
  vpc_zone_identifier = data.aws_subnet_ids.default.ids # Utilise les sous-réseaux récupérés pour l'ASG
  target_group_arns = [aws_lb_target_group.asg.arn] # Associe le groupe d'auto-scaling au target group


  # Définit un tag pour le groupe d'auto-scaling
  tag {
    key = "name"
    propagate_at_launch = false
    value = "Practice_ASG"
  }
 
  # Assure que la ressource est créée avant d'être détruite
  lifecycle {
    create_before_destroy = true
  }
}