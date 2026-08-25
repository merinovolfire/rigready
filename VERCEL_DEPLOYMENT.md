# Move RigReady to Vercel

## Deploy
1. In Vercel, choose **Add New → Project**, import the GitHub `rigready` repository, and choose the **Vite** framework preset if prompted.
2. Before deployment, set these Production environment variables in **Project → Settings → Environment Variables**:
   - `VITE_SUPABASE_URL` — Supabase Project URL
   - `VITE_SUPABASE_ANON_KEY` — Supabase Publishable key
   - `SUPABASE_SERVICE_ROLE_KEY` — Supabase Secret/service-role key (server only; never place it in a `VITE_` variable)
3. Deploy. Test the temporary `*.vercel.app` domain: sign-in, inspection, deficiency, and Add member.

## Squarespace domain
1. In Vercel **Project → Settings → Domains**, add `rigready.merinofire.com`.
2. Vercel gives the exact DNS target. In Squarespace DNS, remove any old `rigready` Netlify record and add the CNAME that Vercel specifies (often `cname.vercel-dns.com`).
3. Wait for Vercel to verify and issue HTTPS. Then update Supabase Auth Site URL and Redirect URL to `https://rigready.merinofire.com`.

## Netlify retirement
Keep Netlify live until the Vercel temporary URL and custom domain are tested. Then remove the custom domain from Netlify; this prevents DNS and certificate conflicts. You may delete the Netlify site afterward.
