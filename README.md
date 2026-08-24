# FireReady
Mobile-first fire apparatus and equipment inspection PWA foundation built with React + TypeScript, Express, and PostgreSQL.

## Start
1. Create PostgreSQL database `fireinspect` and copy `.env.example` to `.env`.
2. `npm install`
3. `npm run db:migrate && npm run db:seed`
4. `npm run dev`

Use `chief@metrofd.test` / `Fire123!` after seeding. All seed records are fictional.

## Security model
- bcrypt password hashes, 12-hour signed JWT, server-side role guards, Zod request validation, SQL parameter binding, audit records.
- The migration enables PostgreSQL RLS and assigns request scope variables (`app.user_id`, `app.role`, `app.station_id`) inside transactions. Run the API with a database role that does **not** bypass RLS.
- Administrator / chief have command visibility; station scoped staff see their station and their own assignments; maintenance receives maintenance-wide deficiency visibility.

## Included domain
Schema includes all requested tables, referential constraints, inspection status enums, inspection failure note validation, generated QR token on apparatus, audit trail, repair history and attachment metadata. Submitted inspection API creates related deficiency records transactionally.

## API
`POST /api/auth/login`, `GET /api/dashboard`, `GET|POST /api/apparatus`, `GET /api/templates/:id`, `POST /api/inspections`, `GET|PATCH /api/deficiencies`, `POST /api/repairs`, `GET /api/export/deficiencies.csv`.

For production, place the PWA build behind TLS and add a service worker / web-push layer according to the chosen deployment platform, use an object-storage signed upload endpoint for attachments, and generate printable PDFs using a server-side renderer or browser print route.
