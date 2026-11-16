# ---------------------------------------------------
# Private form drafts ("Save draft" and "Resume" in the staff portal)
#
# One row per draft. Each staff member can only read and write rows that
# belong to their own sign-in: IAM allows only rows whose "owner" equals the
# person's Cognito identity ID. Drafts are not part of any client record
# and are deleted automatically 30 days after they were last saved.
# Admin is read-only, so the admin role does not get this policy.
# ---------------------------------------------------

resource "aws_dynamodb_table" "form_drafts" {
  name         = "vidacare-form-drafts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "owner"
  range_key    = "draft_id"

  attribute {
    name = "owner"
    type = "S"
  }

  attribute {
    name = "draft_id"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = { Project = "VidaCare" }
}

resource "aws_iam_policy" "form_drafts_own" {
  name        = "vidacare-form-drafts-own"
  description = "Each signed-in staff member can use only their own rows in the form drafts table"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "OwnDraftsOnly"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:Query"]
        Resource = aws_dynamodb_table.form_drafts.arn
        Condition = {
          "ForAllValues:StringEquals" = {
            "dynamodb:LeadingKeys" = ["$${cognito-identity.amazonaws.com:sub}"]
          }
        }
      }
    ]
  })

  tags = { Project = "VidaCare" }
}

resource "aws_iam_role_policy_attachment" "cognito_form_drafts" {
  for_each   = { for k, v in local.department_policies : k => v if k != "admin" }
  role       = aws_iam_role.cognito_department[each.key].name
  policy_arn = aws_iam_policy.form_drafts_own.arn
}
