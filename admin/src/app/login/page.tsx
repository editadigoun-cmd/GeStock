"use client";
import {useState} from "react";

const ADMIN_EMAIL = "editadigoun@gmail.com";

export default function Login(){
 const [email,setEmail]=useState(ADMIN_EMAIL),[password,setPassword]=useState(""),[error,setError]=useState(""),[busy,setBusy]=useState(false),[creating,setCreating]=useState(false);
 async function submit(e:React.FormEvent){
  e.preventDefault();setBusy(true);setError("");
  if(email.trim().toLowerCase()!==ADMIN_EMAIL){setError("Seule l’adresse administrateur autorisée peut accéder à cet espace.");setBusy(false);return;}
  try{
   const endpoint=creating?"/api/auth/sign-up/email":"/api/auth/sign-in/email";
   const payload=creating?{name:"Administrateur GeStock",email:ADMIN_EMAIL,password}:{email:ADMIN_EMAIL,password};
   const r=await fetch(endpoint,{method:"POST",headers:{"Content-Type":"application/json"},credentials:"include",body:JSON.stringify(payload)});
   const result=await r.json().catch(()=>({}));
   if(!r.ok)throw new Error(result?.message||result?.error|| (creating?"Création du compte impossible.":"Connexion refusée. Vérifie ton mot de passe."));
   const s=await fetch("/api/auth/get-session",{credentials:"include",cache:"no-store"});
   const d=await s.json();
   if((d?.user?.email||"").toLowerCase()!==ADMIN_EMAIL)throw new Error(creating?"Compte créé. Connecte-toi avec ton mot de passe.":"Session non reconnue. Réessaie.");
   location.href="/dashboard";
  }catch(x){setError(x instanceof Error?x.message:"Connexion impossible.");}
  finally{setBusy(false);}
 }
 return <main className="login"><form onSubmit={submit}><div className="logo">G</div><small>ESPACE SÉCURISÉ</small><h1>GeStock <i>Admin</i></h1><p>{creating?"Crée le compte administrateur principal.":"Connectez-vous à votre centre de pilotage."}</p><label>E-mail</label><input type="email" required value={email} onChange={e=>setEmail(e.target.value)} placeholder="Adresse e-mail" autoComplete="username"/><label>Mot de passe</label><input type="password" required minLength={8} value={password} onChange={e=>setPassword(e.target.value)} placeholder="Mot de passe" autoComplete={creating?"new-password":"current-password"}/>{creating&&<p className="hint">Choisis un mot de passe personnel d’au moins 8 caractères.</p>}{error&&<div className="error">{error}</div>}<button disabled={busy}>{busy?(creating?"Création…":"Connexion…"):(creating?"Créer mon compte →":"Se connecter →")}</button><button type="button" className="switch-mode" disabled={busy} onClick={()=>{setCreating(!creating);setError("");setPassword("");}}>{creating?"J’ai déjà un compte : me connecter":"Première connexion ? Créer le compte administrateur"}</button><footer>Accès réservé à l’administrateur principal</footer></form></main>
}
