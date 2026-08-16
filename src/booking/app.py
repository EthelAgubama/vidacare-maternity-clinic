import json
import os
import uuid
from datetime import datetime, timezone

import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource("dynamodb")
ses = boto3.client("ses")
sns = boto3.client("sns")

SERVICE_TABLE_NAME = os.environ["SERVICE_TABLE_NAME"]
VISITS_TABLE = os.environ.get("VISITS_TABLE", "vidacare-visits")
PATIENT_RECORDS_TABLE = os.environ.get("PATIENT_RECORDS_TABLE", "vidacare-patient-records")
SERVICE_LABEL = os.environ.get("SERVICE_LABEL", "service")
SENDER_EMAIL = os.environ.get("SENDER_EMAIL", "vidacareclinic@gmail.com")

service_table = dynamodb.Table(SERVICE_TABLE_NAME)
visits_table = dynamodb.Table(VISITS_TABLE)
patients_table = dynamodb.Table(PATIENT_RECORDS_TABLE)

REQUIRED_FIELDS = ["patient_id", "visit_id"]


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body),
    }


def _visit_exists(visit_id, patient_id):
    result = visits_table.query(
        KeyConditionExpression=Key("visit_id").eq(visit_id)
    )
    items = result.get("Items", [])
    if not items:
        return False
    return items[0].get("patient_id") == patient_id


def _get_patient(patient_id):
    result = patients_table.query(
        KeyConditionExpression=Key("patient_id").eq(patient_id)
    )
    items = result.get("Items", [])
    return items[0] if items else None


def _normalize_ghana_phone(phone):
    phone = phone.strip().replace(" ", "").replace("-", "")

    if phone.startswith("+"):
        return phone
    if phone.startswith("233"):
        return f"+{phone}"
    if phone.startswith("0"):
        return f"+233{phone[1:]}"
    return f"+233{phone}"


def _send_confirmation(patient, service_label):
    service_name = service_label.replace("-", " ").title()
    message = (
        f"Hi {patient.get('full_name', 'there')}, your {service_name} "
        f"booking at VidaCare Maternity Clinic has been confirmed. "
        f"We look forward to seeing you."
    )

    email = patient.get("email_address")
    if email:
        try:
            ses.send_email(
                Source=SENDER_EMAIL,
                Destination={"ToAddresses": [email]},
                Message={
                    "Subject": {"Data": f"VidaCare: {service_name} booking confirmed"},
                    "Body": {"Text": {"Data": message}},
                },
            )
        except Exception as exc:  # noqa: BLE001
            print(f"SES send failed: {exc}")

    phone = patient.get("phone_number")
    if phone:
        try:
            sns.publish(
                PhoneNumber=_normalize_ghana_phone(phone),
                Message=message,
            )
        except Exception as exc:  # noqa: BLE001
            print(f"SNS send failed: {exc}")


def handler(event, context):
    try:
        payload = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "Invalid JSON body"})

    missing = [f for f in REQUIRED_FIELDS if not payload.get(f)]
    if missing:
        return _response(400, {"error": f"Missing required field(s): {', '.join(missing)}"})

    patient_id = payload["patient_id"]
    visit_id = payload["visit_id"]

    if not _visit_exists(visit_id, patient_id):
        return _response(404, {"error": f"No matching visit found for visit_id '{visit_id}' and patient_id '{patient_id}'"})

    record_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).isoformat()

    item = {
        "patient_id": patient_id,
        "record_id": record_id,
        "visit_id": visit_id,
        "service_type": SERVICE_LABEL,
        "created_at": now,
    }

    for key, value in payload.items():
        if key not in item and key not in REQUIRED_FIELDS:
            item[key] = value

    try:
        service_table.put_item(Item=item)
    except Exception as exc:  # noqa: BLE001
        return _response(500, {"error": f"Failed to save {SERVICE_LABEL} booking", "details": str(exc)})

    patient = _get_patient(patient_id)
    if patient:
        _send_confirmation(patient, SERVICE_LABEL)

    return _response(201, {
        "record_id": record_id,
        "visit_id": visit_id,
        "patient_id": patient_id,
      "message": f"{SERVICE_LABEL.replace('-', ' ').title()} booking created successfully",
    })