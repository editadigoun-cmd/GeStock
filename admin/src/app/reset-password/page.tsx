"use client";
import {useState} from "react";

export default function ResetPassword(){
 const [password,setPassword]=useState(""),[confirm,setConfirm]=useState(""),[error,setError]=useState(""),[busy,setBusy]=useState(false),[done,setDone]=useState(false);
 async function submit(e:React.FormEvent){
  e.preventDefault();setError("");
  const token=new URLSearchParams(window.location.search).get("token");
  if(!token){setError("Lien invalide ou expiré. Recommence depuis « Mot de passe oublié ».");return;}
  if(password.length<8){setError("Le mot de passe doit contenir au moins 8 caractères.");return;}
  if(password!==confirm){setError("Les deux mots de passe ne correspondent pas.");return;}
  setBusy(true);
  try{
   const r=await fetch("/api/auth/reset-password",{method:"POST",headers:{"Content-Type":"application/json"},credentials:"include",body:JSON.stringify({token,newPassword:password})});
   const raw=await r.text();let data:any={};try{data=raw?JSON.parse(raw):{};}catch{}
   if(!r.ok)throw new Error(data?.message||data?.error||raw||`Erreur HTTP ${r.status}`);
   setDone(true);window.history.replaceState({},document.title,window.location.pathname);
  }catch(err){setError(err instanceof Error?err.message:"Réinitialisation impossible.");}
  finally{setBusy(false);}
 }
 return <main className="login"><form onSubmit={submit}><div className="logo">G</div><small>RÉCUPÉRATION DU COMPTE</small><h1>GeStock <i>Admin</i></h1>{done?<><p>Mot de passe réinitialisé avec succès.</p><a href="/login">Retour à la connexion</a></>:<><p>Définis ton nouveau mot de passe administrateur.</p><label>Nouveau mot de passe</label><input type="password" required minLength={8} autoComplete="new-password" value={password} onChange={e=>setPassword(e.target.value)}/><label>Confirmer le mot de passe</label><input type="password" required minLength={8} autoComplete="new-password" value={confirm} onChange={e=>setConfirm(e.target.value)}/>{error&&<div className="error">{error}</div>}<button disabled={busy}>{busy?"Enregistrement…":"Réinitialiser le mot de passe"}</button></>}</form></main>;
}
