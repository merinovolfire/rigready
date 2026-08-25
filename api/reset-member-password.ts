import type {VercelRequest,VercelResponse} from '@vercel/node';
import {createClient} from '@supabase/supabase-js';
export default async function handler(req:VercelRequest,res:VercelResponse){
 if(req.method!=='POST')return res.status(405).json({error:'Method not allowed'});
 const url=process.env.VITE_SUPABASE_URL,service=process.env.SUPABASE_SERVICE_ROLE_KEY;
 if(!url||!service)return res.status(500).json({error:'Password management is not configured'});
 const token=req.headers.authorization?.replace('Bearer ','');const admin=createClient(url,service);
 const {data:{user}}=await admin.auth.getUser(token);if(!user)return res.status(401).json({error:'Sign in required'});
 const {data:actor}=await admin.from('profiles').select('role').eq('id',user.id).single();
 if(!actor||!['administrator','chief_officer'].includes(actor.role))return res.status(403).json({error:'Only administrators and chiefs can reset passwords'});
 const {member_id,password}=req.body||{};
 if(!member_id||typeof password!=='string'||password.length<10)return res.status(400).json({error:'A new password of at least 10 characters is required'});
 const {error}=await admin.auth.admin.updateUserById(member_id,{password});if(error)return res.status(400).json({error:error.message});
 await admin.from('audit_log').insert({actor_id:user.id,action:'reset_password',entity_type:'user',entity_id:member_id});
 return res.status(200).json({ok:true});
}
