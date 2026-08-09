terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "vidacare-terraform-state-ethel"
    key            = "vidacare/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "vidacare-terraform-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ---------------------------------------------------
# Data layer — one table per record type
# ---------------------------------------------------

resource "aws_dynamodb_table" "visits" {
  name         = "vidacare-visits"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "visit_id"

  attribute {
    name = "visit_id"
    type = "S"
  }

  tags = { Project = "VidaCare" }
}

resource "aws_dynamodb_table" "patient_records" {
  name         = "vidacare-patient-records"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "patient_id"
  range_key    = "record_type"

  attribute {
    name = "patient_id"
    type = "S"
  }

  attribute {
    name = "record_type"
    type = "S"
  }

  tags = { Project = "VidaCare" }
}

resource "aws_dynamodb_table" "antenatal_records" {
  name         = "vidacare-antenatal-records"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "patient_id"
  range_key    = "record_id"

  attribute {
    name = "patient_id"
    type = "S"
  }

  attribute {
    name = "record_id"
    type = "S"
  }

  attribute {
    name = "visit_id"
    type = "S"
  }

  global_secondary_index {
    name            = "visit_id-index"
    hash_key        = "visit_id"
    projection_type = "ALL"
  }

  tags = { Project = "VidaCare" }
}

resource "aws_dynamodb_table" "postnatal_records" {
  name         = "vidacare-postnatal-records"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "patient_id"
  range_key    = "record_id"

  attribute {
    name = "patient_id"
    type = "S"
  }

  attribute {
    name = "record_id"
    type = "S"
  }

  attribute {
    name = "visit_id"
    type = "S"
  }

  global_secondary_index {
    name            = "visit_id-index"
    hash_key        = "visit_id"
    projection_type = "ALL"
  }

  tags = { Project = "VidaCare" }
}

resource "aws_dynamodb_table" "family_planning_records" {
  name         = "vidacare-family-planning-records"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "patient_id"
  range_key    = "record_id"

  attribute {
    name = "patient_id"
    type = "S"
  }

  attribute {
    name = "record_id"
    type = "S"
  }

  attribute {
    name = "visit_id"
    type = "S"
  }

  global_secondary_index {
    name            = "visit_id-index"
    hash_key        = "visit_id"
    projection_type = "ALL"
  }

  tags = { Project = "VidaCare" }
}

resource "aws_dynamodb_table" "child_welfare_records" {
  name         = "vidacare-child-welfare-records"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "patient_id"
  range_key    = "record_id"

  attribute {
    name = "patient_id"
    type = "S"
  }

  attribute {
    name = "record_id"
    type = "S"
  }

  attribute {
    name = "visit_id"
    type = "S"
  }

  global_secondary_index {
    name            = "visit_id-index"
    hash_key        = "visit_id"
    projection_type = "ALL"
  }

  tags = { Project = "VidaCare" }
}

resource "aws_dynamodb_table" "lab_results" {
  name         = "vidacare-lab-results"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "patient_id"
  range_key    = "record_id"

  attribute {
    name = "patient_id"
    type = "S"
  }

  attribute {
    name = "record_id"
    type = "S"
  }

  tags = { Project = "VidaCare" }
}

resource "aws_dynamodb_table" "pharmacy_inventory" {
  name         = "vidacare-pharmacy-inventory"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "item_id"

  attribute {
    name = "item_id"
    type = "S"
  }

  tags = { Project = "VidaCare" }
}

resource "aws_dynamodb_table" "billing" {
  name         = "vidacare-billing"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "patient_id"
  range_key    = "invoice_id"

  attribute {
    name = "patient_id"
    type = "S"
  }

  attribute {
    name = "invoice_id"
    type = "S"
  }

  tags = { Project = "VidaCare" }
}

resource "aws_dynamodb_table" "finance" {
  name         = "vidacare-finance"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "record_id"

  attribute {
    name = "record_id"
    type = "S"
  }

  tags = { Project = "VidaCare" }
}

resource "aws_dynamodb_table" "procurement" {
  name         = "vidacare-procurement"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "order_id"

  attribute {
    name = "order_id"
    type = "S"
  }

  tags = { Project = "VidaCare" }
}

# ---------------------------------------------------
# Shared action sets
# ---------------------------------------------------

locals {
  read_actions = [
    "dynamodb:GetItem",
    "dynamodb:Query",
    "dynamodb:BatchGetItem",
    "dynamodb:Scan"
  ]
  write_actions = [
    "dynamodb:PutItem",
    "dynamodb:UpdateItem",
    "dynamodb:DeleteItem",
    "dynamodb:BatchWriteItem"
  ]
  rw_actions = concat(local.read_actions, local.write_actions)
}

# ---------------------------------------------------
# IAM — one module call per department
# ---------------------------------------------------

module "iam_front_desk" {
  source          = "./modules/iam"
  department_name = "front-desk"
  policy_statements = [
    { sid = "PatientRecordsRW", actions = local.rw_actions, resource_arns = [aws_dynamodb_table.patient_records.arn] },
    { sid = "BillingRead", actions = local.read_actions, resource_arns = [aws_dynamodb_table.billing.arn] },
    { sid = "VisitsRW", actions = local.rw_actions, resource_arns = [aws_dynamodb_table.visits.arn] }
  ]
}

module "iam_antenatal" {
  source          = "./modules/iam"
  department_name = "antenatal"
  policy_statements = [
    { sid = "PatientRecordsRead", actions = local.read_actions, resource_arns = [aws_dynamodb_table.patient_records.arn] },
    { sid = "AntenatalRW", actions = local.rw_actions, resource_arns = ["${aws_dynamodb_table.antenatal_records.arn}", "${aws_dynamodb_table.antenatal_records.arn}/index/*"] },
    { sid = "LabRead", actions = local.read_actions, resource_arns = [aws_dynamodb_table.lab_results.arn] },
    { sid = "VisitsRead", actions = local.read_actions, resource_arns = [aws_dynamodb_table.visits.arn] }
  ]
}

module "iam_postnatal" {
  source          = "./modules/iam"
  department_name = "postnatal"
  policy_statements = [
    { sid = "PatientRecordsRead", actions = local.read_actions, resource_arns = [aws_dynamodb_table.patient_records.arn] },
    { sid = "PostnatalRW", actions = local.rw_actions, resource_arns = ["${aws_dynamodb_table.postnatal_records.arn}", "${aws_dynamodb_table.postnatal_records.arn}/index/*"] },
    { sid = "LabRead", actions = local.read_actions, resource_arns = [aws_dynamodb_table.lab_results.arn] },
    { sid = "VisitsRead", actions = local.read_actions, resource_arns = [aws_dynamodb_table.visits.arn] }
  ]
}

module "iam_family_planning" {
  source          = "./modules/iam"
  department_name = "family-planning"
  policy_statements = [
    { sid = "PatientRecordsRead", actions = local.read_actions, resource_arns = [aws_dynamodb_table.patient_records.arn] },
    { sid = "FamilyPlanningRW", actions = local.rw_actions, resource_arns = ["${aws_dynamodb_table.family_planning_records.arn}", "${aws_dynamodb_table.family_planning_records.arn}/index/*"] },
    { sid = "VisitsRead", actions = local.read_actions, resource_arns = [aws_dynamodb_table.visits.arn] }
  ]
}

module "iam_child_welfare" {
  source          = "./modules/iam"
  department_name = "child-welfare"
  policy_statements = [
    { sid = "PatientRecordsRead", actions = local.read_actions, resource_arns = [aws_dynamodb_table.patient_records.arn] },
    { sid = "ChildWelfareRW", actions = local.rw_actions, resource_arns = ["${aws_dynamodb_table.child_welfare_records.arn}", "${aws_dynamodb_table.child_welfare_records.arn}/index/*"] },
    { sid = "LabRead", actions = local.read_actions, resource_arns = [aws_dynamodb_table.lab_results.arn] },
    { sid = "VisitsRead", actions = local.read_actions, resource_arns = [aws_dynamodb_table.visits.arn] }
  ]
}

module "iam_lab" {
  source          = "./modules/iam"
  department_name = "lab"
  policy_statements = [
    { sid = "AntenatalRead", actions = local.read_actions, resource_arns = [aws_dynamodb_table.antenatal_records.arn] },
    { sid = "PostnatalRead", actions = local.read_actions, resource_arns = [aws_dynamodb_table.postnatal_records.arn] },
    { sid = "FamilyPlanningRead", actions = local.read_actions, resource_arns = [aws_dynamodb_table.family_planning_records.arn] },
    { sid = "ChildWelfareRead", actions = local.read_actions, resource_arns = [aws_dynamodb_table.child_welfare_records.arn] },
    { sid = "LabRW", actions = local.rw_actions, resource_arns = [aws_dynamodb_table.lab_results.arn] }
  ]
}

module "iam_pharmacy" {
  source          = "./modules/iam"
  department_name = "pharmacy"
  policy_statements = [
    { sid = "AntenatalRead", actions = local.read_actions, resource_arns = [aws_dynamodb_table.antenatal_records.arn] },
    { sid = "PostnatalRead", actions = local.read_actions, resource_arns = [aws_dynamodb_table.postnatal_records.arn] },
    { sid = "FamilyPlanningRead", actions = local.read_actions, resource_arns = [aws_dynamodb_table.family_planning_records.arn] },
    { sid = "InventoryRW", actions = local.rw_actions, resource_arns = [aws_dynamodb_table.pharmacy_inventory.arn] },
    { sid = "BillingWrite", actions = local.write_actions, resource_arns = [aws_dynamodb_table.billing.arn] }
  ]
}

module "iam_billing" {
  source          = "./modules/iam"
  department_name = "billing"
  policy_statements = [
    { sid = "BillingRW", actions = local.rw_actions, resource_arns = [aws_dynamodb_table.billing.arn] }
  ]
}

module "iam_finance" {
  source          = "./modules/iam"
  department_name = "finance"
  policy_statements = [
    { sid = "BillingRead", actions = local.read_actions, resource_arns = [aws_dynamodb_table.billing.arn] },
    { sid = "FinanceRW", actions = local.rw_actions, resource_arns = [aws_dynamodb_table.finance.arn] },
    { sid = "ProcurementRead", actions = local.read_actions, resource_arns = [aws_dynamodb_table.procurement.arn] }
  ]
}

module "iam_procurement" {
  source          = "./modules/iam"
  department_name = "procurement"
  policy_statements = [
    { sid = "InventoryRW", actions = local.rw_actions, resource_arns = [aws_dynamodb_table.pharmacy_inventory.arn] },
    { sid = "ProcurementRW", actions = local.rw_actions, resource_arns = [aws_dynamodb_table.procurement.arn] }
  ]
}

module "iam_clinicians" {
  source          = "./modules/iam"
  department_name = "clinicians"
  policy_statements = [
    { sid = "PatientRecordsRW", actions = local.rw_actions, resource_arns = [aws_dynamodb_table.patient_records.arn] },
    { sid = "AntenatalRW", actions = local.rw_actions, resource_arns = ["${aws_dynamodb_table.antenatal_records.arn}", "${aws_dynamodb_table.antenatal_records.arn}/index/*"] },
    { sid = "PostnatalRW", actions = local.rw_actions, resource_arns = ["${aws_dynamodb_table.postnatal_records.arn}", "${aws_dynamodb_table.postnatal_records.arn}/index/*"] },
    { sid = "FamilyPlanningRW", actions = local.rw_actions, resource_arns = ["${aws_dynamodb_table.family_planning_records.arn}", "${aws_dynamodb_table.family_planning_records.arn}/index/*"] },
    { sid = "ChildWelfareRW", actions = local.rw_actions, resource_arns = ["${aws_dynamodb_table.child_welfare_records.arn}", "${aws_dynamodb_table.child_welfare_records.arn}/index/*"] },
    { sid = "LabRead", actions = local.read_actions, resource_arns = [aws_dynamodb_table.lab_results.arn] },
    { sid = "InventoryRead", actions = local.read_actions, resource_arns = [aws_dynamodb_table.pharmacy_inventory.arn] },
    { sid = "VisitsRW", actions = local.rw_actions, resource_arns = [aws_dynamodb_table.visits.arn] }
  ]
}

module "iam_admin" {
  source          = "./modules/iam"
  department_name = "admin"
  policy_statements = [
    { sid = "AllTablesRead", actions = local.read_actions, resource_arns = [
      aws_dynamodb_table.patient_records.arn,
      aws_dynamodb_table.antenatal_records.arn,
      aws_dynamodb_table.postnatal_records.arn,
      aws_dynamodb_table.family_planning_records.arn,
      aws_dynamodb_table.child_welfare_records.arn,
      aws_dynamodb_table.lab_results.arn,
      aws_dynamodb_table.pharmacy_inventory.arn,
      aws_dynamodb_table.billing.arn,
      aws_dynamodb_table.finance.arn,
      aws_dynamodb_table.procurement.arn,
      aws_dynamodb_table.visits.arn
    ] }
  ]
}