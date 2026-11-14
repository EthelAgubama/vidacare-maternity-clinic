# ---------------------------------------------------
# Prescriptions: clinicians prescribe, the pharmacy dispenses.
# Each prescription carries a small snapshot of the client (name, client ID,
# age, sex, allergies) because the pharmacy cannot read patient records.
# Stock lives in the existing vidacare-pharmacy-inventory table.
# Dispensing writes an unpaid line to vidacare-billing for the Billing department.
# ---------------------------------------------------

resource "aws_dynamodb_table" "prescriptions" {
  name         = "vidacare-prescriptions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "rx_id"

  attribute {
    name = "rx_id"
    type = "S"
  }

  tags = { Project = "VidaCare" }
}
