

resource "aws_security_group" "alb-sg" {
  name        = format("%s-alb-sg", var.component_name)
  description = "Allow allow http and https access}"
  vpc_id      = local.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = format("%s-alb-sg", var.component_name)
  }
}

resource "aws_security_group_rule" "alb-ingress-http-rule" {
  security_group_id = aws_security_group.alb-sg.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb-ingress-https-rule" {
  security_group_id = aws_security_group.alb-sg.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group" "postgres-sg" {
  name        = format("%s-postgres-sg", var.component_name)
  description = "Allow ecs cluster on port ${var.container_port}"
  vpc_id      = local.vpc_id

  tags = {
    Name = format("%s-postgres-sg", var.component_name)
  }
}

resource "aws_security_group_rule" "postgres-ingress-rule" {
  security_group_id        = aws_security_group.postgres-sg.id
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs-sg.id
}

resource "aws_security_group" "ecs-sg" {
  name        = format("%s-ecs-sg", var.component_name) # "${ var.component_name}-postgres-sg"
  description = "Allow alb  on port ${var.container_port}"
  vpc_id      = local.vpc_id

  tags = {
    Name = format("%s-ecs-sg", var.component_name)
  }
}

resource "aws_security_group_rule" "ecs-ingress-rule" {
  security_group_id        = aws_security_group.ecs-sg.id
  type                     = "ingress"
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb-sg.id
}


resource "aws_security_group_rule" "allow_ecs_egress_rule" {
  security_group_id = aws_security_group.ecs-sg.id
  type              = "egress"
  protocol          = "-1"
  to_port           = 0
  from_port         = 0
  cidr_blocks       = ["0.0.0.0/0"]
}
