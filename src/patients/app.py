import json
import os
import re
import uuid
from datetime import datetime, timezone

import boto3

dynamodb = boto3.resource("dynamodb")
TABLE_NAME = os.environ.get("PATIENT_RECORDS_TABLE", "vidacare-patient-records")
table = dynamodb.Table(TABLE_NAME)

REQUIRED_FIELDS = [
    "full_name",
    "date_of_birth",
    "phone_number",
    "gender",
    "address",
    "emergency_contact_name",
    "emergency_contact_phone",
    "emergency_contact_relationship",
]

OPTIONAL_FIELDS = [
    "nhis_number",
    "ghana_card_number",
    "blood_group",
    "allergies",
]

PHONE_PATTERN = re.compile(r"^\+?\d{9,15}$")
DATE_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body),
    }


def _validate(payload):
    errors = []

    for field in REQUIRED_FIELDS:
        value = payload.get(field)
        if not value or not str(value).strip():
            errors.append(f"'{field}' is required")

    phone = payload.get("phone_number", "")
    if phone and not PHONE_PATTERN.match(phone):
        errors.append("'phone_number' must be a valid phone number")

    emergency_phone = payload.get("emergency_contact_phone", "")
    if emergency_phone and not PHONE_PATTERN.match(emergency_phone):
        errors.append("'emergency_contact_phone' must be a valid phone number")

    dob = payload.get("date_of_birth", "")
    if dob and not DATE_PATTERN.match(dob):
        errors.append("'date_of_birth' must be in YYYY-MM-DD format")

    return errors


def handler(event, context):
    try:
        payload = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "Invalid JSON body"})

    validation_errors = _validate(payload)
    if validation_errors:
        return _response(400, {"error": "Validation failed", "details": validation_errors})

    patient_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).isoformat()

    item = {
        "patient_id": patient_id,
        "record_type": "registration",
        "created_at": now,
    }

    for field in REQUIRED_FIELDS:
        item[field] = payload[field]

    for field in OPTIONAL_FIELDS:
        if payload.get(field):
            item[field] = payload[field]

    try:
        table.put_item(Item=item)
    except Exception as exc:  # noqa: BLE001
        return _response(500, {"error": "Failed to save patient record", "details": str(exc)})

    return _response(201, {"patient_id": patient_id, "message": "Patient registered successfully"})