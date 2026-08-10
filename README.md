# VidaCare Maternity Clinic

This is a cloud project I built to model how a maternity clinic could run securely on AWS — specifically, how different departments in a clinic should only be able to see the patient data relevant to their job, and nothing more.

The idea came out of my time working with a hospital information system called Oasis, where I noticed how access was split across departments like pharmacy, front desk, and finance. I wanted to recreate that same logic using proper cloud infrastructure, so this project became a working example of role-based access control, built entirely with Terraform on AWS.

## What it does

VidaCare lets a patient register once, open a visit, and then get booked into whichever clinical services they need during that visit — antenatal care, postnatal care, family planning, child welfare, or labour and delivery. Each of those services lives in its own database table, and each department in the clinic only has the permissions it actually needs to do its job.

For example, a pharmacist can check a patient's antenatal notes to confirm what was prescribed and can bill for the medication dispensed, but has no access to finance records or procurement orders. A cashier can process payments but can't touch the accounting ledger. Front desk can register a patient and see billing status, but can't view clinical notes. This mirrors how access actually worked at Oasis, just rebuilt using AWS IAM instead of application-level permissions.

## How it's built

- **Lambda (Python)** handles all the application logic — registering patients, opening visits, and creating bookings
- **API Gateway** exposes everything as real HTTP endpoints
- **DynamoDB** stores the data, with a separate table for each type of record
- **IAM** enforces who can access what, at the infrastructure level — twelve department groups, each with a tightly scoped policy
- **Terraform** manages all of it, with the state stored remotely in S3 and locked via DynamoDB so nothing gets corrupted if I'm working from more than one machine

## The booking flow

Registration and visits are separate from the actual services, on purpose:

1. `POST /patients` — a patient registers once and gets a `patient_id`
2. `POST /visits` — a visit is opened using that `patient_id`, returning a `visit_id`
3. `POST /bookings/{service}` — one or more services get booked against that same visit

That last step is what makes it possible for a patient to be seen for antenatal care and family planning counselling on the same visit, without those two departments ever seeing each other's records. They're just linked by a shared `visit_id`.

The five service endpoints are: `/bookings/antenatal`, `/bookings/postnatal`, `/bookings/family-planning`, `/bookings/child-welfare`, and `/bookings/labour-delivery`.

## Departments and access

The full access matrix — who can read, who can write, who has no access at all — is written out in [`docs/architecture.md`](docs/architecture.md). The short version: clinicians have broad clinical access, admin can see everything but only in read-only mode for oversight, and everyone else is scoped tightly to their own department's data plus whatever cross-department reads make sense in practice (like pharmacy being able to read antenatal notes, or finance being able to read billing).

## Project layout
vidacare-maternity-clinic/
├── terraform/
│ ├── main.tf # DynamoDB tables, IAM groups and policies, Lambda execution role
│ ├── lambda_api.tf # Lambda functions and API Gateway routes
│ └── modules/iam/ # Reusable module that builds one IAM group + policy per department
├── src/
│ ├── patients/ # Patient registration
│ ├── visits/ # Visit creation
│ └── booking/ # Shared booking logic, reused across all five services
├── docs/
│ └── architecture.md # Access matrix and design notes
└── README.md


## Where things stand

The core of the system — registration, visits, and all five service bookings — is built, deployed, and tested end to end against live AWS infrastructure. Still to come: appointment notifications, a proper booking interface on the frontend, and monitoring/CI-CD to round it out.

## About this project

I'm Ethel Agubama Akanzire, building this for my mother and part of building projects, alongside my broader work in data analytics and cloud engineering.
