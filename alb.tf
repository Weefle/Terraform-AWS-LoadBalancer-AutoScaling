// Création d'un groupe de sécurité pour l'Application Load Balancer
resource "aws_security_group" "alb-sec-group" {
  name = "alb-sec-group"  // Nom du groupe de sécurité
  description = "Security Group for the ELB (ALB)"  // Description du groupe de sécurité


  // Règle sortante pour autoriser tout le trafic (tout protocole, toutes les adresses IP)
  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }


  // Règle entrante pour autoriser le trafic HTTP (port 80, toutes les adresses IP)
  ingress {
    from_port = 80
    protocol = "tcp"
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
  }


  // Règle entrante pour autoriser le trafic HTTPS (port 443, toutes les adresses IP)
  ingress {
    from_port = 443
    protocol = "tcp"
    to_port = 443
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Crée un load balancer applicatif
resource "aws_lb" "ELB" {
  name = "terraform-asg-example" # Nom du load balancer
  load_balancer_type = "application" # Type de load balancer


  # Utilise les sous-réseaux récupérés pour le load balancer
  subnets  = data.aws_subnet_ids.default.ids


  # Utilise le groupe de sécurité associé au load balancer
  security_groups = [aws_security_group.alb-sec-group.id]
}


# Crée une règle pour le listener HTTP
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ELB.arn # Utilise le load balancer créé précédemment
  port = 80 # Port utilisé pour le listener
  protocol = "HTTP" # Utilise le protocole HTTP pour le listener


  # Définit une action par défaut si aucune condition n'est remplie
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}


# Définit un groupe cible pour l'Auto Scaling Group
resource "aws_lb_target_group" "asg" {
  name = "asg-example"
  port = var.ec2_instance_port
  protocol = "HTTP"
  vpc_id = data.aws_vpc.default.id


  # Configure le Health Check pour le groupe cible
  health_check {
    path = "/"
    protocol = "HTTP"
    matcher = "200"
    interval = 15
    timeout = 3
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}

# Récupère les ID des sous-réseaux de la VPC AWS
data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}


# Crée une règle d'écoute pour le Load Balancer qui redirige le trafic vers le groupe cible
resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority = 100


  # Configure l'action de la règle pour rediriger le trafic vers le groupe cible
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
    # Configure la condition de la règle pour rediriger tous les chemins d'accès vers le groupe cible
  condition {
    path_pattern {
      values = ["*"]
    }
  }
}