resource "aws_iam_group" "this" {
  name = "vidacare-${var.department_name}"
}

resource "aws_iam_policy" "this" {
  name = "vidacare-${var.department_name}-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      for s in var.policy_statements : {
        Sid      = s.sid
        Effect   = "Allow"
        Action   = s.actions
        Resource = s.resource_arns
      }
    ]
  })
}

resource "aws_iam_group_policy_attachment" "this" {
  group      = aws_iam_group.this.name
  policy_arn = aws_iam_policy.this.arn
}