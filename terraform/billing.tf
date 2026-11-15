resource "aws_dynamodb_table" "service_prices" {
  name         = "vidacare-service-prices"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "price_id"

  attribute {
    name = "price_id"
    type = "S"
  }

  tags = { Project = "VidaCare" }
}
