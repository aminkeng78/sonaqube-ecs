


resource "aws_lb" "alb_sonar" {
  name               = "${var.component_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb-sg.id]
  subnets            = local.public_subnet

  tags = {
    Name = "${var.component_name}-sonar"
  }
}


resource "aws_lb_target_group" "sonar_target_group" {
  depends_on = [aws_lb.alb_sonar]

  name        = lower("${var.component_name}-tg-group")
  target_type = "ip" # IF FARGET
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = local.vpc_id

  load_balancing_algorithm_type = "round_robin"
  health_check {
    healthy_threshold   = "2"
    interval            = "90"
    protocol            = "HTTP"
    port                = "9000"
    matcher             = "200"
    timeout             = "60"
    path                = "/"
    unhealthy_threshold = "7"
  }
  tags = {
    Name = "${var.component_name}-target-group"
  }
}

resource "aws_lb_listener" "sonar_listener_redirect" {
  load_balancer_arn = aws_lb.alb_sonar.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "sonar_listener" {
  load_balancer_arn = aws_lb.alb_sonar.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = module.acm.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sonar_target_group.arn
  }
}


data "aws_route53_zone" "zone" {
  name = "${var.dns_zone_name}."
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "3.0.0"

  domain_name               = trimsuffix(data.aws_route53_zone.zone.name, ".")
  zone_id                   = data.aws_route53_zone.zone.zone_id
  subject_alternative_names = var.subject_alternative_names
}

resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = var.dns_zone_name
  type    = "A"

  alias {
    name                   = aws_lb.alb_sonar.dns_name
    zone_id                = aws_lb.alb_sonar.zone_id
    evaluate_target_health = true
  }
}