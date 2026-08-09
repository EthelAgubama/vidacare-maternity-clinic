variable "department_name" {
  type        = string
  description = "Short name for the department, e.g. front-desk"
}

variable "policy_statements" {
  type = list(object({
    sid           = string
    actions       = list(string)
    resource_arns = list(string)
  }))
  description = "List of IAM policy statements for this department"
}
