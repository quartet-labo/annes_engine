# Customer Management Sample

This is a small internal Rails host application that uses both engines in this repository.

- `anne_auth` handles staff admin login.
- `anne_admin` provides the admin CRUD screens for customers, persons, organizations, customer contacts, and projects.

## Customer Model

The sample supports both individual and organization customers.

- `customers` is the shared customer ledger used by projects and internal workflows.
- `persons` stores individual information.
- `organizations` stores company, shop, and group information.
- `customer_contacts` stores contact roles for each customer.

`organization_members` is intentionally not part of the first sample. Add it when the app needs organization membership history, multiple organization memberships per person, or organization chart style management beyond customer contacts.

## Setup

From this directory:

```sh
bundle install
bin/rails db:setup
bin/rails server
```

Open <http://localhost:3000>.

Seed users:

- Admin: `admin@example.com` / `password`

## Screens

- Admin login: <http://localhost:3000/admin/login>
- Admin dashboard: <http://localhost:3000/admin>

## Database

The sample uses PostgreSQL. To point it at a specific database, set:

```sh
export CUSTOMER_MANAGEMENT_DATABASE_URL=postgres://postgres:password@127.0.0.1:5432/anne_customer_management_development
```
