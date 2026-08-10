# ---------------------------------------------------
# Package the Lambda source code
# ---------------------------------------------------

data "archive_file" "patients_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src/patients"
  output_path = "${path.module}/../src/patients.zip"
}

# ---------------------------------------------------
# Lambda function: patient registration
# ---------------------------------------------------

resource "aws_lambda_function" "patients" {
  function_name    = "vidacare-patients"
  filename         = data.archive_file.patients_zip.output_path
  source_code_hash = data.archive_file.patients_zip.output_base64sha256
  handler          = "app.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  timeout          = 10

  environment {
    variables = {
      PATIENT_RECORDS_TABLE = aws_dynamodb_table.patient_records.name
    }
  }

  tags = { Project = "VidaCare" }
}

# ---------------------------------------------------
# API Gateway (HTTP API) — shared across all booking endpoints
# ---------------------------------------------------

resource "aws_apigatewayv2_api" "vidacare_api" {
  name          = "vidacare-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "GET", "OPTIONS"]
    allow_headers = ["content-type"]
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.vidacare_api.id
  name        = "$default"
  auto_deploy = true
}

# ---------------------------------------------------
# Route: POST /patients
# ---------------------------------------------------

resource "aws_apigatewayv2_integration" "patients" {
  api_id                 = aws_apigatewayv2_api.vidacare_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.patients.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "patients_post" {
  api_id    = aws_apigatewayv2_api.vidacare_api.id
  route_key = "POST /patients"
  target    = "integrations/${aws_apigatewayv2_integration.patients.id}"
}

resource "aws_lambda_permission" "patients_api_gw" {
  statement_id  = "AllowAPIGatewayInvokePatients"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.patients.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.vidacare_api.execution_arn}/*/*"
}

# ---------------------------------------------------
# Output the API base URL
# ---------------------------------------------------

output "api_base_url" {
  value = aws_apigatewayv2_stage.default.invoke_url
}
# ---------------------------------------------------
# Package the Lambda source code — visits
# ---------------------------------------------------

data "archive_file" "visits_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src/visits"
  output_path = "${path.module}/../src/visits.zip"
}

# ---------------------------------------------------
# Lambda function: visit creation
# ---------------------------------------------------

resource "aws_lambda_function" "visits" {
  function_name    = "vidacare-visits"
  filename         = data.archive_file.visits_zip.output_path
  source_code_hash = data.archive_file.visits_zip.output_base64sha256
  handler          = "app.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  timeout          = 10

  environment {
    variables = {
      VISITS_TABLE           = aws_dynamodb_table.visits.name
      PATIENT_RECORDS_TABLE  = aws_dynamodb_table.patient_records.name
    }
  }

  tags = { Project = "VidaCare" }
}

# ---------------------------------------------------
# Route: POST /visits
# ---------------------------------------------------

resource "aws_apigatewayv2_integration" "visits" {
  api_id                 = aws_apigatewayv2_api.vidacare_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.visits.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "visits_post" {
  api_id    = aws_apigatewayv2_api.vidacare_api.id
  route_key = "POST /visits"
  target    = "integrations/${aws_apigatewayv2_integration.visits.id}"
}

resource "aws_lambda_permission" "visits_api_gw" {
  statement_id  = "AllowAPIGatewayInvokeVisits"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visits.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.vidacare_api.execution_arn}/*/*"
}