import { useEffect, useState } from 'react'
import type { Session, User } from '@supabase/supabase-js'
import { isSupabaseConfigured, supabase } from '../../lib/supabase'
export function useSession(){const [session,setSession]=useState<Session|null>(null);const [loading,setLoading]=useState(true);useEffect(()=>{if(!supabase)return;let active=true;void supabase.auth.getSession().then(({data})=>{if(active){setSession(data.session);setLoading(false)}});const {data}=supabase.auth.onAuthStateChange((_event,next)=>{if(active){setSession(next);setLoading(false)}});return()=>{active=false;data.subscription.unsubscribe()}},[]);return{session,user:session?.user as User|undefined,loading,isSupabaseConfigured}}
export async function signOut(){if(!supabase)return;await supabase.auth.signOut()}
