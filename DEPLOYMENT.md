# RigReady deployment plan — Merino Volunteer Fire Department

**Public application URL:** `https://rigready.merinofire.com`

This deployment does **not** require Cloudflare. Squarespace remains the registrar/DNS manager for `merinofire.com`.

## Services
- **Supabase:** PostgreSQL, department authentication, row-level security, and private photo storage.
- **Netlify:** secure static hosting for the React PWA, automatic HTTPS, and GitHub deployments.
- **Squarespace Domains/DNS:** DNS management for `merinofire.com`.

## Configure Supabase
1. Create a Supabase project in US East named **RigReady — Merino VFD**. Save its database password offline.
2. In SQL Editor, paste and run `supabase/migrations/001_rigready.sql`.
3. In **Authentication → Providers**, enable Email. Turn **off** public sign-ups after the initial administrator is created.
4. In **Authentication → URL Configuration**, set Site URL to `https://rigready.merinofire.com` and add that exact URL as a Redirect URL.
5. Create the first administrator in Authentication. Then insert a matching `profiles` record using their Auth user UUID and role `administrator`.
6. Copy only the **Project URL** and browser-safe **anon/publishable key**. Never expose the `service_role` key in the browser, Netlify, or GitHub.

## Deploy the application through Netlify
1. Create a free Netlify account and select **Add new site → Import an existing project**.
2. Authorize GitHub and select the private `rigready` repository.
3. Netlify will read `netlify.toml`. Confirm build command is `npm run build` and publish folder is `dist`.
4. In **Site configuration → Environment variables**, add `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` from `.env.production.example`.
5. Deploy. Netlify creates a temporary `*.netlify.app` address; test it before connecting the department domain.

## Connect the Squarespace-managed domain
1. In Netlify, open **Domain management → Add a domain → Add domain alias** and add `rigready.merinofire.com`.
2. Netlify will show the exact DNS target. In Squarespace **Domains → merinofire.com → DNS Settings**, add a **CNAME** record:
   - **Host/Name:** `rigready`
   - **Points to/Data:** the Netlify target (normally the temporary `your-site.netlify.app` hostname shown by Netlify)
3. Remove an existing `rigready` A, CNAME, URL-forwarding, or parking record if Squarespace reports a conflict.
4. Wait for DNS validation. Netlify automatically provisions the TLS/HTTPS certificate.
5. Confirm that `https://rigready.merinofire.com` loads and that Supabase sign-in redirects return to the same address.

## Operational minimum
- Export a Supabase database backup weekly to department-controlled encrypted storage.
- Make two department-owned administrator accounts.
- Do not put patient, incident, or other protected information into inspection attachments.
- Review member access when staffing changes.

## First administrator
For the first account created before the profile trigger was active, run:
```sql
insert into public.profiles (id,display_name,role,active)
select u.id,coalesce(u.raw_user_meta_data->>'display_name',split_part(u.email,'@',1)),'administrator',true
from auth.users u where lower(u.email)=lower('ADMIN_EMAIL')
on conflict(id) do update set role='administrator',active=true;
```
