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

LOGO_URL = "https://vidacare-frontend-ethel.s3.amazonaws.com/assets/vidacare-logo.jpg"


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
    patient_name = patient.get("full_name", "Patient")

    sms_message = (
        f"Dear {patient_name}, this is to confirm that your {service_name} "
        f"appointment at VidaCare Maternity Home has been successfully scheduled. "
        f"We look forward to welcoming you."
    )

    html_body = f"""
    <html>
    <body style="margin:0;padding:0;background-color:#E8F5E9;font-family:Georgia,'Times New Roman',serif;color:#1A1A1A;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#E8F5E9;padding:32px 0;">
        <tr>
          <td align="center">
            <table role="presentation" width="520" cellpadding="0" cellspacing="0" style="background-color:#FFFFFF;border-radius:12px;overflow:hidden;box-shadow:0 4px 18px rgba(27,94,32,0.12);">
              <tr>
                <td align="center" style="background-color:#1B5E20;padding:28px 20px;">
                  <img src="{LOGO_URL}" width="72" height="72" alt="VidaCare Maternity Home" style="border-radius:50%;display:block;margin-bottom:10px;">
                  <div style="color:#FFFFFF;font-size:20px;font-weight:bold;letter-spacing:0.02em;">VidaCare Maternity Home</div>
                </td>
              </tr>
              <tr>
                <td style="padding:32px 36px;">
                  <p style="font-size:15px;line-height:1.6;margin:0 0 16px;">Dear {patient_name},</p>
                  <p style="font-size:15px;line-height:1.6;margin:0 0 16px;">
                    We are pleased to confirm that your appointment for <strong style="color:#1B5E20;">{service_name}</strong>
                    has been successfully scheduled with VidaCare Maternity Home.
                  </p>
                  <p style="font-size:15px;line-height:1.6;margin:0 0 24px;">
                    Should you have any questions or need to make changes to this appointment, please do not
                    hesitate to contact our office in advance of your visit.
                  </p>
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#E8F5E9;border-radius:8px;padding:4px;">
                    <tr>
                      <td style="padding:14px 18px;font-size:14px;">
                        <strong style="color:#1B5E20;">Service:</strong> {service_name}<br>
                        <strong style="color:#1B5E20;">Status:</strong> Confirmed
                      </td>
                    </tr>
                  </table>
                  <p style="font-size:14px;line-height:1.6;color:#555555;margin:26px 0 0;">
                    Yours sincerely,<br>
                    <strong>VidaCare Maternity Home</strong>
                  </p>
                </td>
              </tr>
              <tr>
                <td align="center" style="background-color:#E8F5E9;padding:16px;font-size:12px;color:#777777;">
                  This is an automated confirmation from VidaCare Maternity Home.
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>
    """

    text_body = (
        f"Dear {patient_name},\n\n"
        f"We are pleased to confirm that your appointment for {service_name} has been "
        f"successfully scheduled with VidaCare Maternity Home.\n\n"
        f"Should you have any questions or need to make changes to this appointment, "
        f"please contact our office in advance of your visit.\n\n"
        f"Yours sincerely,\nVidaCare Maternity Home"
    )

    email = patient.get("email_address")
    if email:
        try:
            ses.send_email(
                Source=SENDER_EMAIL,
                Destination={"ToAddresses": [email]},
                Message={
                    "Subject": {"Data": f"VidaCare Maternity Home — {service_name} Appointment Confirmation"},
                    "Body": {
                        "Html": {"Data": html_body},
                        "Text": {"Data": text_body},
                    },
                },
            )
        except Exception as exc:  # noqa: BLE001
            print(f"SES send failed: {exc}")

    phone = patient.get("phone_number")
    if phone:
        try:
            sns.publish(
                PhoneNumber=_normalize_ghana_phone(phone),
                Message=sms_message,
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