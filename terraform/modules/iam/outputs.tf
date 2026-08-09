output "group_name" {
  value = aws_iam_group.this.name
}

output "group_arn" {
  value = aws_iam_group.this.arn
}

output "policy_arn" {
  value = aws_iam_policy.this.arn
}
