import {createClient} from '@supabase/supabase-js';
const url=import.meta.env.VITE_SUPABASE_URL, key=import.meta.env.VITE_SUPABASE_ANON_KEY;
if(!url||!key) console.warn('RigReady needs Supabase environment variables');
export const supabase=createClient(url||'https://placeholder.supabase.co',key||'placeholder');
