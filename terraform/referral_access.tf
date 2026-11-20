# ---------------------------------------------------------------
# Referral access: clinicians can see a summary of an antenatal,
# postnatal or child welfare record ONLY while a midwife's referral
# to a clinician is open. Every look is logged.
# ---------------------------------------------------------------

resource "aws_dynamodb_table" "referral_access" {
  name         = "vidacare-referral-access"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "referral_id"

  attribute {
    name = "referral_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = { Project = "VidaCare" }
}

data "archive_file" "referral_access" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_referral_access"
  output_path = "${path.module}/referral_access.zip"
}

resource "aws_iam_role" "referral_access" {
  name = "vidacare-referral-access-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "referral_access_logs" {
  role       = aws_iam_role.referral_access.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Read-only on the clinical tables; read and write only on the referral table.
resource "aws_iam_role_policy" "referral_access" {
  name = "vidacare-referral-access-policy"
  role = aws_iam_role.referral_access.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:Scan"]
        Resource = [
          aws_dynamodb_table.patient_records.arn,
          aws_dynamodb_table.antenatal_records.arn,
          aws_dynamodb_table.postnatal_records.arn,
          aws_dynamodb_table.child_welfare_records.arn,
          aws_dynamodb_table.prescriptions.arn,
          aws_dynamodb_table.lab_requests.arn,
          aws_dynamodb_table.lab_results.arn
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:Scan", "dynamodb:PutItem", "dynamodb:UpdateItem"]
        Resource = [aws_dynamodb_table.referral_access.arn]
      }
    ]
  })
}

resource "aws_lambda_function" "referral_access" {
  function_name    = "vidacare-referral-access"
  role             = aws_iam_role.referral_access.arn
  runtime          = "nodejs20.x"
  handler          = "index.handler"
  filename         = data.archive_file.referral_access.output_path
  source_code_hash = data.archive_file.referral_access.output_base64sha256
  timeout          = 15
  memory_size      = 256

  environment {
    variables = {
      REFERRAL_TABLE = aws_dynamodb_table.referral_access.name
      PATIENT_TABLE  = aws_dynamodb_table.patient_records.name
      ANC_TABLE      = aws_dynamodb_table.antenatal_records.name
      PN_TABLE       = aws_dynamodb_table.postnatal_records.name
      CW_TABLE       = aws_dynamodb_table.child_welfare_records.name
      RX_TABLE       = aws_dynamodb_table.prescriptions.name
      LABREQ_TABLE   = aws_dynamodb_table.lab_requests.name
      LABRES_TABLE   = aws_dynamodb_table.lab_results.name
    }
  }

  tags = { Project = "VidaCare" }
}

resource "aws_apigatewayv2_api" "referral_access" {
  name          = "vidacare-referral-access"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["http://vidacare-frontend-prod.s3-website-us-east-1.amazonaws.com"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["authorization", "content-type"]
    max_age       = 3600
  }
}

# API Gateway checks the Cognito sign-in token before the function runs.
resource "aws_apigatewayv2_authorizer" "referral_access" {
  api_id           = aws_apigatewayv2_api.referral_access.id
  name             = "cognito-jwt"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    audience = ["5usb6pdhbmd3bl9t24dmtrutgc"]
    issuer   = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_jesPtVohe"
  }
}

resource "aws_apigatewayv2_integration" "referral_access" {
  api_id                 = aws_apigatewayv2_api.referral_access.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.referral_access.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "referral_access" {
  for_each           = toset(["GET /referrals", "GET /referrals/{id}", "POST /referrals/{id}/seen"])
  api_id             = aws_apigatewayv2_api.referral_access.id
  route_key          = each.value
  target             = "integrations/${aws_apigatewayv2_integration.referral_access.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.referral_access.id
}

resource "aws_apigatewayv2_stage" "referral_access" {
  api_id      = aws_apigatewayv2_api.referral_access.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 20
    throttling_rate_limit  = 10
  }
}

resource "aws_lambda_permission" "referral_access" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.referral_access.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.referral_access.execution_arn}/*/*"
}

# The portal reads its service address from this small file, so no hand-editing is needed.
resource "aws_s3_object" "portal_config" {
  bucket       = "vidacare-frontend-prod"
  key          = "staff-portal/config.json"
  content_type = "application/json"
  content      = jsonencode({ referral_api = aws_apigatewayv2_api.referral_access.api_endpoint })
}

output "referral_api_url" {
  value = aws_apigatewayv2_api.referral_access.api_endpoint
}
