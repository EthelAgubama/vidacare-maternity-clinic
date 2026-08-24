# ---------------------------------------------------
# S3 bucket for static frontend hosting
# ---------------------------------------------------

resource "aws_s3_bucket" "frontend" {
  bucket = "vidacare-frontend-prod"

  tags = { Project = "VidaCare" }
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "vidacare-booking.html"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls       = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "frontend_public_read" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

resource "aws_s3_object" "booking_page" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "vidacare-booking.html"
  source       = "${path.module}/../frontend/vidacare-booking.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/../frontend/vidacare-booking.html")
}

output "frontend_url" {
 value = "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}"
}
resource "aws_s3_object" "logo" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "assets/vidacare-logo.jpg"
  source       = "${path.module}/../frontend/assets/vidacare-logo.jpg"
  content_type = "image/jpeg"
  etag         = filemd5("${path.module}/../frontend/assets/vidacare-logo.jpg")
}