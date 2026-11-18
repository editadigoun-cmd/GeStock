"use client";
import {useState} from "react";
export default function Login(){
 const [email,setEmail]=useState(""),[password,setPassword]=useState(""),[error,setError]=useState(""),[busy,setBusy]=useState(false);
 async function submit(e:React.FormEvent){e.preventDefault();setBusy(true);setError("");try{
  const r=await fetch("/api/auth/sign-in/email",{method:"POST",headers:{"Content-Type":"application/json"},credentials:"include",body:JSON.stringify({email,password})});
  if(!r.ok)throw new Error("Identifiants incorrects ou compte non créé.");
  const s=await fetch("/api/auth/get-session",{credentials:"include",cache:"no-store"});const d=await s.json();
  if((d?.user?.email||"").toLowerCase()!=="editadigoun@gmail.com")throw new Error("Adresse non autorisée pour l’administration.");
  location.href="/dashboard";
 }catch(x){setError(x instanceof Error?x.message:"Connexion impossible.");}finally{setBusy(false)}}
 return <main className="login"><form onSubmit={submit}><div className="logo">G</div><small>ESPACE SÉCURISÉ</small><h1>GeStock <i>Admin</i></h1><p>Connectez-vous à votre centre de pilotage.</p><label>E-mail</label><input type="email" required value={email} onChange={e=>setEmail(e.target.value)} placeholder="Adresse e-mail"/><label>Mot de passe</label><input type="password" required value={password} onChange={e=>setPassword(e.target.value)} placeholder="Mot de passe"/>{error&&<div className="error">{error}</div>}<button disabled={busy}>{busy?"Connexion…":"Se connecter →"}</button><footer>Accès réservé à l’administrateur principal</footer></form></main>
}