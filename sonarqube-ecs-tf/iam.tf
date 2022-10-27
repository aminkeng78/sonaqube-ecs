

data "aws_iam_policy_document" "ecs_task_execution_role" {

  version = "2012-10-17"
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com", "ecs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "iam_for_ecs" {
  name_prefix        = "${var.component_name}-sonar"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_role.json
}

resource "aws_iam_role_policy_attachment" "task_execution_role" {
  role       = aws_iam_role.iam_for_ecs.name
  policy_arn = aws_iam_policy.ecs.arn
}

resource "aws_iam_policy" "ecs" {
  name_prefix = format("%s-%s", var.component_name, "sonar")
  path        = "/"
  description = "IAM policy to allow ${var.component_name}-sonar have access"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
          "application-autoscaling:*",
          "autoscaling:*",
          "apigateway:*",
          "cloudfront:*",
          "cloudwatch:*",
          "cloudformation:*",
          "dax:*",
          "dynamodb:*",
          "ec2:*",
          "ec2messages:*",
          "ecr:*",
          "ecs:*",
          "elasticfilesystem:*",
          "elasticache:*",
          "elasticloadbalancing:*",
          "es:*",
          "events:*",
          "iam:*",
          "kms:*",
          "lambda:*",
          "logs:*",
          "rds:*",
          "route53:*",
          "ssm:*",
          "ssmmessages:*",
          "s3:*",
          "sns:*",
          "sqs:*",
          "ec2:DescribeNetworkInterfaces",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeInstances",
          "ec2:AttachNetworkInterface"
      ],
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
EOF
}