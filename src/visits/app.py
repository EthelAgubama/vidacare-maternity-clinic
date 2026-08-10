import json
import os
import uuid
from datetime import datetime, timezone

import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource("dynamodb")
VISITS_TABLE = os.environ.get("VISITS_TABLE", "vidacare-visits")
PATIENT_RECORDS_TABLE = os.environ.get("PATIENT_RECORDS_TABLE", "vidacare-patient-records")

visits_table = dynamodb.Table(VISITS_TABLE)
patients_table = dynamodb.Table(PATIENT_RECORDS_TABLE)


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body),
    }


def _patient_exists(patient_id):
    result = patients_table.query(
        KeyConditionExpression=Key("patient_id").eq(patient_id)
    )
    return result.get("Count", 0) > 0


def handler(event, context):
    try:
        payload = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "Invalid JSON body"})

    patient_id = payload.get("patient_id")
    if not patient_id or not str(patient_id).strip():
        return _response(400, {"error": "'patient_id' is required"})

    if not _patient_exists(patient_id):
        return _response(404, {"error": f"No patient found with patient_id '{patient_id}'"})

    visit_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).isoformat()

    item = {
        "visit_id": visit_id,
        "patient_id": patient_id,
        "visit_date": payload.get("visit_date", now),
        "created_at": now,
        "status": "open",
    }

    try:
        visits_table.put_item(Item=item)
    except Exception as exc:  # noqa: BLE001
        return _response(500, {"error": "Failed to create visit", "details": str(exc)})

    return _response(201, {"visit_id": visit_id, "patient_id": patient_id, "message": "Visit created successfully"})