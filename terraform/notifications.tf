# ---------------------------------------------------
# SES — verified sender identity
# ---------------------------------------------------

resource "aws_ses_email_identity" "sender" {
  email = "vidacareclinic@gmail.com"
}

# ---------------------------------------------------
# SNS — topic for SMS notifications
# ---------------------------------------------------

resource "aws_sns_topic" "booking_notifications" {
  name = "vidacare-booking-notifications"
  tags = { Project = "VidaCare" }
}

# ---------------------------------------------------
# IAM — allow the booking Lambdas to send via SES and SNS
# ---------------------------------------------------

resource "aws_iam_role_policy" "lambda_notifications" {
  name = "vidacare-lambda-notifications-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = "*"
      }
    ]
  })
}