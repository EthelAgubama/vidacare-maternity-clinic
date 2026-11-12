# ---------------------------------------------------
# Lab requests: clinicians request tests, the lab fills in and releases results.
# Finished results stay in vidacare-lab-results (lab write only).
# Each request carries a small snapshot of patient identity (name, client ID,
# age, sex) because the lab department cannot read patient records.
# ---------------------------------------------------

resource "aws_dynamodb_table" "lab_requests" {
  name         = "vidacare-lab-requests"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "request_id"

  attribute {
    name = "request_id"
    type = "S"
  }

  tags = { Project = "VidaCare" }
}
