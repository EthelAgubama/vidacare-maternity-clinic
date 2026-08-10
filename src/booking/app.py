import json
import os
import uuid
from datetime import datetime, timezone

import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource("dynamodb")

SERVICE_TABLE_NAME = os.environ["SERVICE_TABLE_NAME"]
VISITS_TABLE = os.environ.get("VISITS_TABLE", "vidacare-visits")
SERVICE_LABEL = os.environ.get("SERVICE_LABEL", "service")

service_table = dynamodb.Table(SERVICE_TABLE_NAME)
visits_table = dynamodb.Table(VISITS_TABLE)

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

    return _response(201, {
        "record_id": record_id,
        "visit_id": visit_id,
        "patient_id": patient_id,
        "message": f"{SERVICE_LABEL.replace('-', ' ').title()} booking created successfully",
    })
