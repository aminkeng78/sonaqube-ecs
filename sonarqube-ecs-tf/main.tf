terraform {
  required_version = ">=1.1.5"

  backend "s3" {
    bucket         = "deploy-ecsbucket"
    dynamodb_table = "terraform-lock"
    key            = "path/env"
    region         = "us-east-1"
    encrypt        = "true"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = local.required_tags
  }
}

locals {
  required_tags = {
    line_of_business        = "kojitechs"
    ado                     = "max"
    tier                    = "WEB"
    operational_environment = upper(terraform.workspace)
    tech_poc_primary        = "conilius@gmail.com"
    tech_poc_secondary      = "conilius@gmail.com"
    application             = "http"
    builder                 = "conilius@gmail.com"
    application_owner       = "conilius.com"
    vpc                     = "WEB"
    cell_name               = "WEB"
    component_name          = var.component_name
  }
  azs            = data.aws_availability_zones.available.names
  vpc_id         = module.vpc.vpc_id
  public_subnet  = module.vpc.public_subnets
  private_subnet = module.vpc.private_subnets
  db_subnets_names = module.vpc.database_subnet_group_name
  name              = "kojitechs-${replace(basename(var.component_name), "_", "-")}"
  account_id       = data.aws_caller_identity.current.account_id
  database_secrets = jsondecode(data.aws_secretsmanager_secret_version.secret-version.secret_string)
}


data "aws_secretsmanager_secret_version" "secret-version" {
  depends_on = [module.aurora]
  secret_id  = module.aurora.secrets_version
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}



module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.component_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = local.azs
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform = "true"
    
  }
}


module "aurora" {
   source = "git::https://github.com/Bkoji1150/aws-rdscluster-kojitechs-tf.git?ref=v1.1.11"

  component_name = var.component_name
  name           = local.name
  engine         = "aurora-postgresql"
  engine_version = "11.15"
  instances = {
    1 = {
      instance_class      = "db.r5.2xlarge"
      publicly_accessible = false
    }
  }

  vpc_id                 = local.vpc_id 
  create_db_subnet_group = true
  subnets                = local.private_subnet

  create_security_group = true
  vpc_security_group_ids =  [aws_security_group.postgres-sg.id]
  iam_database_authentication_enabled = true

  apply_immediately   = true
  skip_final_snapshot = true

  enabled_cloudwatch_logs_exports = ["postgresql"]
  database_name                   = var.database_name
  master_username                 = var.master_username
}

resource "aws_cloudwatch_log_group" "sonar" {
  name = format("cidc-%s", var.component_name)

  tags = {
    Name = format("cidc-%s", var.component_name)
  }
}

resource "aws_ecs_cluster" "sonar" {
  name = upper(format("cidc-%s", var.component_name))

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "sonar" {
  depends_on = [module.aurora]

  requires_compatibilities = [
    "FARGATE",
  ]

  family             = format("%s-task-def", var.component_name)
  task_role_arn      = aws_iam_role.iam_for_ecs.arn
  execution_role_arn = aws_iam_role.iam_for_ecs.arn
  network_mode       = "awsvpc"
  cpu                = 4096 # 4 vCPU
  memory             = 8192 # 8 GB
  container_definitions = jsonencode([
    {
      name = format("%s-sonar", var.component_name)
      image = format(
        "%s.dkr.ecr.us-east-1.amazonaws.com/%s:%s",
        "6742-9348-8770",
        var.container_name,
        var.container_version
      )
      essential = true
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "${aws_cloudwatch_log_group.sonar.name}",
          awslogs-region        = "${data.aws_region.current.name}",
          awslogs-stream-prefix = "${aws_cloudwatch_log_group.sonar.name}-sonar"
        }
      },

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
        }
      ],
      command = ["-Dsonar.search.javaAdditionalOpts=-Dnode.store.allow_mmap=false"]
      environment = [
        {
          name  = "SONAR_JDBC_USERNAME"
          value = "${local.database_secrets["username"]}" # 
        },
        {
          name  = "SONAR_JDBC_PASSWORD"
          value = "${local.database_secrets["password"]}"
        },
        {
          name  = "SONAR_JDBC_URL"
          value = "jdbc:postgresql://${local.database_secrets["endpoint"]}/${local.database_secrets["dbname"]}?sslmode=require"
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "sonar" {
  name            = upper(format("%s-service", var.component_name))
  cluster         = aws_ecs_cluster.sonar.id
  task_definition = aws_ecs_task_definition.sonar.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs-sg.id]
    subnets          = local.private_subnet
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.sonar_target_group.arn
    container_name   = format("%s-sonar", var.component_name)
    container_port   = var.container_port
  }
}

