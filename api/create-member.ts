import type {VercelRequest,VercelResponse} from '@vercel/node';
import {createClient} from '@supabase/supabase-js';

export default async function handler(req:VercelRequest,res:VercelResponse){
  if(req.method!=='POST') return res.status(405).json({error:'Method not allowed'});
  const url=process.env.VITE_SUPABASE_URL, service=process.env.SUPABASE_SERVICE_ROLE_KEY;
  if(!url||!service) return res.status(500).json({error:'Server member provisioning is not configured'});
  const token=req.headers.authorization?.replace('Bearer ','');
  const admin=createClient(url,service);
  const {data:{user},error:userError}=await admin.auth.getUser(token);
  if(userError||!user)return res.status(401).json({error:'Sign in required'});
  const {data:actor}=await admin.from('profiles').select('role').eq('id',user.id).single();
  if(!actor||!['administrator','chief_officer'].includes(actor.role))return res.status(403).json({error:'Only administrators and chiefs can create member accounts'});
  const {email,password,display_name,role,station_id}=req.body||{};
  if(!email||!password||!display_name||!role)return res.status(400).json({error:'Name, email, temporary password, and role are required'});
  const {data,error}=await admin.auth.admin.createUser({email,password,email_confirm:true,user_metadata:{display_name}});
  if(error)return res.status(400).json({error:error.message});
  await admin.from('profiles').upsert({id:data.user.id,display_name,role,station_id:station_id||null,active:true});
  await admin.from('audit_log').insert({actor_id:user.id,action:'create',entity_type:'user',entity_id:data.user.id,detail:{email,role}});
  return res.status(201).json({id:data.user.id,email});
}
