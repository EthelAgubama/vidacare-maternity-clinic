# ---------------------------------------------------
# Cognito User Pool — staff logins
# ---------------------------------------------------

resource "aws_cognito_user_pool" "staff" {
  name = "vidacare-staff"

  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  password_policy {
    minimum_length    = 10
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true
  }

  auto_verified_attributes = []

  tags = { Project = "VidaCare" }
}

resource "aws_cognito_user_pool_client" "staff_client" {
  name         = "vidacare-staff-client"
  user_pool_id = aws_cognito_user_pool.staff.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  generate_secret = false
}

# ---------------------------------------------------
# Department groups — one per IAM department
# ---------------------------------------------------

locals {
  department_policies = {
    "front-desk"      = module.iam_front_desk.policy_arn
    "antenatal"       = module.iam_antenatal.policy_arn
    "postnatal"       = module.iam_postnatal.policy_arn
    "family-planning" = module.iam_family_planning.policy_arn
    "child-welfare"   = module.iam_child_welfare.policy_arn
    "lab"             = module.iam_lab.policy_arn
    "pharmacy"        = module.iam_pharmacy.policy_arn
    "billing"         = module.iam_billing.policy_arn
    "finance"         = module.iam_finance.policy_arn
    "procurement"     = module.iam_procurement.policy_arn
    "clinicians"      = module.iam_clinicians.policy_arn
    "admin"           = module.iam_admin.policy_arn
  }
}

resource "aws_cognito_user_group" "department" {
  for_each     = local.department_policies
  name         = each.key
  user_pool_id = aws_cognito_user_pool.staff.id
  description  = "VidaCare ${each.key} department staff"
}

# ---------------------------------------------------
# Identity Pool — converts a Cognito login into real AWS credentials
# ---------------------------------------------------

resource "aws_cognito_identity_pool" "staff" {
  identity_pool_name              = "vidacare_staff_identity_pool"
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.staff_client.id
    provider_name            = aws_cognito_user_pool.staff.endpoint
    server_side_token_check = false
  }
}

# ---------------------------------------------------
# IAM roles — one per department, trusted by the Identity Pool
# ---------------------------------------------------

resource "aws_iam_role" "cognito_department" {
  for_each = local.department_policies
  name     = "vidacare-cognito-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.staff.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  tags = { Project = "VidaCare" }
}

resource "aws_iam_role_policy_attachment" "cognito_department" {
  for_each   = local.department_policies
  role       = aws_iam_role.cognito_department[each.key].name
  policy_arn = each.value
}

# ---------------------------------------------------
# Default roles (authenticated user not in any group, and unauthenticated)
# ---------------------------------------------------

resource "aws_iam_role" "cognito_default_authenticated" {
  name = "vidacare-cognito-default-authenticated"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.staff.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  tags = { Project = "VidaCare" }
}

resource "aws_iam_role" "cognito_unauthenticated" {
  name = "vidacare-cognito-unauthenticated"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.staff.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "unauthenticated"
          }
        }
      }
    ]
  })

  tags = { Project = "VidaCare" }
}

# ---------------------------------------------------
# Role mapping — a Cognito group membership becomes real AWS access
# ---------------------------------------------------

resource "aws_cognito_identity_pool_roles_attachment" "staff" {
  identity_pool_id = aws_cognito_identity_pool.staff.id

  roles = {
    authenticated   = aws_iam_role.cognito_default_authenticated.arn
    unauthenticated = aws_iam_role.cognito_unauthenticated.arn
  }

  role_mapping {
    identity_provider         = "${aws_cognito_user_pool.staff.endpoint}:${aws_cognito_user_pool_client.staff_client.id}"
    ambiguous_role_resolution = "Deny"
    type                      = "Rules"

    dynamic "mapping_rule" {
      for_each = local.department_policies
      content {
        claim      = "cognito:groups"
        match_type = "Contains"
        value      = mapping_rule.key
        role_arn   = aws_iam_role.cognito_department[mapping_rule.key].arn
      }
    }
  }
}

# ---------------------------------------------------
# Outputs
# ---------------------------------------------------

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.staff.id
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.staff_client.id
}

output "cognito_identity_pool_id" {
  value = aws_cognito_identity_pool.staff.id
}