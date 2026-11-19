"use client";
import {useState} from "react";

const ADMIN_EMAIL = "editadigoun@gmail.com";

export default function Login(){
 const [email,setEmail]=useState(ADMIN_EMAIL),[password,setPassword]=useState(""),[error,setError]=useState(""),[busy,setBusy]=useState(false),[creating,setCreating]=useState(false),[notice,setNotice]=useState("");
 async function submit(e:React.FormEvent){
  e.preventDefault();setBusy(true);setError("");setNotice("");
  if(email.trim().toLowerCase()!==ADMIN_EMAIL){setError("Seule l’adresse administrateur autorisée peut accéder à cet espace.");setBusy(false);return;}
  try{
   const endpoint=creating?"/api/auth/sign-up/email":"/api/auth/sign-in/email";
   const payload=creating?{name:"Administrateur GeStock",email:ADMIN_EMAIL,password}:{email:ADMIN_EMAIL,password};
   const r=await fetch(endpoint,{method:"POST",headers:{"Content-Type":"application/json"},credentials:"include",body:JSON.stringify(payload)});
   const raw=await r.text();
   let result:any={}; try{result=raw?JSON.parse(raw):{};}catch{}
   if(!r.ok){const detail=result?.message||result?.error||result?.code||raw.slice(0,180)||"Réponse vide du serveur";throw new Error(`${creating?"Création refusée":"Connexion refusée"} (HTTP ${r.status}) : ${detail}`);}
   const s=await fetch("/api/auth/get-session",{credentials:"include",cache:"no-store"});
   const d=await s.json();
   if((d?.user?.email||"").toLowerCase()!==ADMIN_EMAIL)throw new Error(creating?"Compte créé. Connecte-toi avec ton mot de passe.":"Session non reconnue. Réessaie.");
   location.href="/dashboard";
  }catch(x){setError(x instanceof Error?x.message:"Connexion impossible.");}
  finally{setBusy(false);}
 }
 async function forgot(){
  setBusy(true);setError("");setNotice("");
  try{
   const r=await fetch("/api/auth/request-password-reset",{method:"POST",headers:{"Content-Type":"application/json"},credentials:"include",body:JSON.stringify({email:ADMIN_EMAIL,redirectTo:window.location.origin+"/reset-password"})});
   const raw=await r.text();let data:any={};try{data=raw?JSON.parse(raw):{};}catch{}
   if(!r.ok)throw new Error(data?.message||data?.error||raw||`Erreur HTTP ${r.status}`);
   setNotice("Si la demande est acceptée, un lien de réinitialisation sera envoyé à l’adresse administrateur. Vérifie ta boîte mail et tes spams.");
  }catch(err){setError(err instanceof Error?err.message:"Impossible d’envoyer la demande de réinitialisation.");}
  finally{setBusy(false);}
 }
 return <main className="login"><form onSubmit={submit}><div className="logo">G</div><small>ESPACE SÉCURISÉ</small><h1>GeStock <i>Admin</i></h1><p>{creating?"Crée le compte administrateur principal.":"Connectez-vous à votre centre de pilotage."}</p><label>E-mail</label><input type="email" required value={email} onChange={e=>setEmail(e.target.value)} placeholder="Adresse e-mail" autoComplete="username"/><label>Mot de passe</label><input type="password" required minLength={8} value={password} onChange={e=>setPassword(e.target.value)} placeholder="Mot de passe" autoComplete={creating?"new-password":"current-password"}/>{creating&&<p className="hint">Choisis un mot de passe personnel d’au moins 8 caractères.</p>}{error&&<div className="error">{error}</div>}{notice&&<div className="hint">{notice}</div>}<button disabled={busy}>{busy?(creating?"Création…":"Connexion…"):(creating?"Créer mon compte →":"Se connecter →")}</button>{!creating&&<button type="button" className="switch-mode" disabled={busy} onClick={forgot}>Mot de passe oublié ?</button>}<button type="button" className="switch-mode" disabled={busy} onClick={()=>{setCreating(!creating);setError("");setNotice("");setPassword("");}}>{creating?"J’ai déjà un compte : me connecter":"Première connexion ? Créer le compte administrateur"}</button><footer>Accès réservé à l’administrateur principal</footer></form></main>
}
