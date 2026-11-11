# VidaCare Roadmap — Phases 9-16

Building on the completed foundation (Phases 1-8: infrastructure, IAM/RBAC design, booking API, notifications, and the patient-facing booking frontend), this next stretch makes the role-based access model real and usable by actual clinic staff.

## Phase 9: Authentication foundation (Cognito)
Amazon Cognito User Pool with one group per department, matching the 12 IAM groups already built. Staff accounts are created by an admin (no public self-signup, matching how a real clinic onboards staff). Login issues temporary AWS credentials scoped to the department's existing IAM policy.

## Phase 10: Dashboard shell
One shared login page and dashboard frame that reads the logged-in user's department and routes them to the right view.

## Phase 11: Front desk, Clinicians, Billing dashboards
First department dashboards, reusing data already flowing through the booking system.

## Phase 12: Lab and Pharmacy dashboards

## Phase 13: Clinical service dashboards
Antenatal, Postnatal, Family Planning, Child Welfare, Labour and Delivery.

## Phase 14: Finance, Procurement, Admin dashboards

## Phase 15: End-to-end access verification, all 12 departments
Test IAM user per department, confirming access boundaries hold across the entire system, not just antenatal (which was verified in Phase 4).

## Phase 16: Monitoring, CI/CD, and documentation
CloudWatch, GitHub Actions, Hava.io architecture diagram, final write-up.
## Phase 17+ (future, post-launch): Clinical data model upgrade
Ideas from a hospital-system reference design, worth adopting once VidaCare has real patient volume:
- Coverage (NHIS/insurance/cash) as its own entity with effective dates, separate from the patient record
- Episodes (pregnancy, CWC enrolment, FP enrolment) with `next_due_date`, powering a defaulter/missed-visit worklist
- Configurable service pathways (queue steps per department) instead of hardcoded flow
- Full field-level audit trail on every edit (who, when, old value, new value)
- Ghana Data Protection Act (Act 843) compliance review: field-level encryption for identifiers, access logging, record-level privacy for sensitive services (e.g. family planning)
Not adopted: relational DB migration, wristband/ZPL printing, NHIS claims integration, till reconciliation — out of scope for current architecture and clinic size.