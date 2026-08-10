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
# ---------------------------------------------------
# Package the Lambda source code — service bookings
# ---------------------------------------------------

data "archive_file" "booking_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src/booking"
  output_path = "${path.module}/../src/booking.zip"
}

# ---------------------------------------------------
# Lambda functions — one per service, same code, different table
# ---------------------------------------------------

resource "aws_lambda_function" "booking_antenatal" {
  function_name    = "vidacare-booking-antenatal"
  filename         = data.archive_file.booking_zip.output_path
  source_code_hash = data.archive_file.booking_zip.output_base64sha256
  handler          = "app.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  timeout          = 10

  environment {
    variables = {
      SERVICE_TABLE_NAME = aws_dynamodb_table.antenatal_records.name
      VISITS_TABLE        = aws_dynamodb_table.visits.name
      SERVICE_LABEL        = "antenatal"
    }
  }

  tags = { Project = "VidaCare" }
}

resource "aws_lambda_function" "booking_postnatal" {
  function_name    = "vidacare-booking-postnatal"
  filename         = data.archive_file.booking_zip.output_path
  source_code_hash = data.archive_file.booking_zip.output_base64sha256
  handler          = "app.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  timeout          = 10

  environment {
    variables = {
      SERVICE_TABLE_NAME = aws_dynamodb_table.postnatal_records.name
      VISITS_TABLE        = aws_dynamodb_table.visits.name
      SERVICE_LABEL        = "postnatal"
    }
  }

  tags = { Project = "VidaCare" }
}

resource "aws_lambda_function" "booking_family_planning" {
  function_name    = "vidacare-booking-family-planning"
  filename         = data.archive_file.booking_zip.output_path
  source_code_hash = data.archive_file.booking_zip.output_base64sha256
  handler          = "app.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  timeout          = 10

  environment {
    variables = {
      SERVICE_TABLE_NAME = aws_dynamodb_table.family_planning_records.name
      VISITS_TABLE        = aws_dynamodb_table.visits.name
      SERVICE_LABEL        = "family-planning"
    }
  }

  tags = { Project = "VidaCare" }
}

resource "aws_lambda_function" "booking_child_welfare" {
  function_name    = "vidacare-booking-child-welfare"
  filename         = data.archive_file.booking_zip.output_path
  source_code_hash = data.archive_file.booking_zip.output_base64sha256
  handler          = "app.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  timeout          = 10

  environment {
    variables = {
      SERVICE_TABLE_NAME = aws_dynamodb_table.child_welfare_records.name
      VISITS_TABLE        = aws_dynamodb_table.visits.name
      SERVICE_LABEL        = "child-welfare"
    }
  }

  tags = { Project = "VidaCare" }
}

resource "aws_lambda_function" "booking_labour_delivery" {
  function_name    = "vidacare-booking-labour-delivery"
  filename         = data.archive_file.booking_zip.output_path
  source_code_hash = data.archive_file.booking_zip.output_base64sha256
  handler          = "app.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  timeout          = 10

  environment {
    variables = {
      SERVICE_TABLE_NAME = aws_dynamodb_table.labour_delivery_records.name
      VISITS_TABLE        = aws_dynamodb_table.visits.name
      SERVICE_LABEL        = "labour-delivery"
    }
  }

  tags = { Project = "VidaCare" }
}

# ---------------------------------------------------
# Routes — one per service
# ---------------------------------------------------

resource "aws_apigatewayv2_integration" "booking_antenatal" {
  api_id                 = aws_apigatewayv2_api.vidacare_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.booking_antenatal.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "booking_antenatal_post" {
  api_id    = aws_apigatewayv2_api.vidacare_api.id
  route_key = "POST /bookings/antenatal"
  target    = "integrations/${aws_apigatewayv2_integration.booking_antenatal.id}"
}

resource "aws_lambda_permission" "booking_antenatal_api_gw" {
  statement_id  = "AllowAPIGatewayInvokeBookingAntenatal"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.booking_antenatal.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.vidacare_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "booking_postnatal" {
  api_id                 = aws_apigatewayv2_api.vidacare_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.booking_postnatal.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "booking_postnatal_post" {
  api_id    = aws_apigatewayv2_api.vidacare_api.id
  route_key = "POST /bookings/postnatal"
  target    = "integrations/${aws_apigatewayv2_integration.booking_postnatal.id}"
}

resource "aws_lambda_permission" "booking_postnatal_api_gw" {
  statement_id  = "AllowAPIGatewayInvokeBookingPostnatal"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.booking_postnatal.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.vidacare_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "booking_family_planning" {
  api_id                 = aws_apigatewayv2_api.vidacare_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.booking_family_planning.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "booking_family_planning_post" {
  api_id    = aws_apigatewayv2_api.vidacare_api.id
  route_key = "POST /bookings/family-planning"
  target    = "integrations/${aws_apigatewayv2_integration.booking_family_planning.id}"
}

resource "aws_lambda_permission" "booking_family_planning_api_gw" {
  statement_id  = "AllowAPIGatewayInvokeBookingFamilyPlanning"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.booking_family_planning.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.vidacare_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "booking_child_welfare" {
  api_id                 = aws_apigatewayv2_api.vidacare_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.booking_child_welfare.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "booking_child_welfare_post" {
  api_id    = aws_apigatewayv2_api.vidacare_api.id
  route_key = "POST /bookings/child-welfare"
  target    = "integrations/${aws_apigatewayv2_integration.booking_child_welfare.id}"
}

resource "aws_lambda_permission" "booking_child_welfare_api_gw" {
  statement_id  = "AllowAPIGatewayInvokeBookingChildWelfare"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.booking_child_welfare.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.vidacare_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "booking_labour_delivery" {
  api_id                 = aws_apigatewayv2_api.vidacare_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.booking_labour_delivery.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "booking_labour_delivery_post" {
  api_id    = aws_apigatewayv2_api.vidacare_api.id
  route_key = "POST /bookings/labour-delivery"
  target    = "integrations/${aws_apigatewayv2_integration.booking_labour_delivery.id}"
}

resource "aws_lambda_permission" "booking_labour_delivery_api_gw" {
  statement_id  = "AllowAPIGatewayInvokeBookingLabourDelivery"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.booking_labour_delivery.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.vidacare_api.execution_arn}/*/*"
}