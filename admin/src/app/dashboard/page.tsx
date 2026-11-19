"use client";
import {useEffect,useState} from "react";
type Health={ok?:boolean;service?:string;version?:string;database?:string;table_count?:number};
type Status={api:Health|null;d1:Health|null;checkedAt:string;errors:string[]};
const adminEmail="editadigoun@gmail.com";
const modules=[["Utilisateurs","Comptes et rôles"],["Entreprises","Organisations et espaces"],["Abonnements","Offres et facturation"],["Publicités","Monétisation"],["Fonctionnalités","Modules activables"],["Support","Assistance"],["Sécurité","Sessions et événements"],["Suivi technique","API et synchronisation"],["Paramètres","Configuration"]];
export default function Dashboard(){
 const[email,setEmail]=useState("");const[authMode,setAuthMode]=useState("");const[status,setStatus]=useState<Status|null>(null);const[loading,setLoading]=useState(true);
 async function refresh(){setLoading(true);try{const r=await fetch("/api/status",{cache:"no-store"});setStatus(await r.json());}catch{setStatus({api:null,d1:null,checkedAt:new Date().toISOString(),errors:["Diagnostic indisponible"]});}finally{setLoading(false);}}
 useEffect(()=>{let live=true;(async()=>{try{const access=await fetch("/api/access/identity",{cache:"no-store"}).then(r=>r.ok?r.json():null);if(access?.email?.toLowerCase()===adminEmail){if(live){setEmail(adminEmail);setAuthMode("Cloudflare Access");}}else{const session=await fetch("/api/auth/get-session",{credentials:"include",cache:"no-store"}).then(r=>r.ok?r.json():null);if(session?.user?.email?.toLowerCase()!==adminEmail){location.replace("/login");return;}if(live){setEmail(adminEmail);setAuthMode("Neon Auth");}}if(live)await refresh();}catch{location.replace("/login");}})();return()=>{live=false;};},[]);
 async function logout(){if(authMode==="Cloudflare Access"){location.href="/cdn-cgi/access/logout";return;}await fetch("/api/auth/sign-out",{method:"POST",credentials:"include"});location.href="/login";}
 const ok=(v?:boolean)=>v===true;
 const serviceRow=(symbol:string,name:string,detail:string,available:boolean|undefined)=> <div className="service-row" key={name}><div className="service-icon">{symbol}</div><div className="service-copy"><b>{name}</b><small>{detail}</small></div><span className={"service-state "+(available===undefined?"pending":available?"good":"bad")}>{loading?"En cours":available===undefined?"À vérifier":available?"Disponible":"Échec"}</span></div>;
 return <div className="admin-shell">
  <aside className="admin-sidebar"><div className="admin-brand"><span className="brand-mark">G</span><div><b>GeStock</b><small>ADMIN CONTROL</small></div></div><div className="sidebar-label">PILOTAGE</div><a className="sidebar-link active" href="/dashboard">◈ &nbsp; Vue générale</a><div className="sidebar-label">PLATEFORME</div>{modules.map(([n,d])=><div className="sidebar-module" key={n}><span>◇</span><div><b>{n}</b><small>{d}</small></div></div>)}<div className="admin-profile"><b>Administrateur</b><small>{email}</small><button onClick={logout}>Déconnexion</button></div></aside>
  <main className="admin-main"><header className="admin-topbar"><span>GeStock <span className="crumb">/</span> Console</span><div className="admin-top-right"><span className="session-pill">{authMode||"Session"}</span><span className="online-dot">●</span></div></header>
   <section className="admin-welcome"><div><small>CONSOLE DE PILOTAGE</small><h1>Bonjour, administrateur.</h1><p>État des services et supervision de la plateforme.</p></div><button className="refresh" onClick={refresh} disabled={loading}>{loading?"Vérification…":"↻ Actualiser"}</button></section>
   <section className="status-grid">
    <article className="status-card"><div className="status-head"><span>API GeStock</span><i className={ok(status?.api?.ok)?"status-good":"status-bad"}>{loading?"…":ok(status?.api?.ok)?"OPÉRATIONNEL":"INDISPONIBLE"}</i></div><strong>{status?.api?.service||"gestock-api"}</strong><p>{status?.api?.version?"Version "+status.api.version:"Endpoint santé"}</p></article>
    <article className="status-card"><div className="status-head"><span>Base de données</span><i className={ok(status?.d1?.ok)?"status-good":"status-bad"}>{loading?"…":ok(status?.d1?.ok)?"OPÉRATIONNEL":"INDISPONIBLE"}</i></div><strong>{status?.d1?.table_count??"—"} tables</strong><p>{status?.d1?.database||"Cloudflare D1"}</p></article>
    <article className="status-card"><div className="status-head"><span>Authentification</span><i className={authMode?"status-good":"status-bad"}>{authMode?"ACTIVE":"À VÉRIFIER"}</i></div><strong>{authMode||"—"}</strong><p>Session administrateur</p></article>
    <article className="status-card"><div className="status-head"><span>Dernier contrôle</span><i className="status-neutral">DIAGNOSTIC</i></div><strong>{status?.checkedAt?new Date(status.checkedAt).toLocaleTimeString("fr-FR",{hour:"2-digit",minute:"2-digit"}):"—"}</strong><p>{status?.checkedAt?new Date(status.checkedAt).toLocaleDateString("fr-FR"):"En attente"}</p></article>
   </section>
   <section className="admin-panel"><div className="panel-title"><div><h2>État des services</h2><p>Vérifications réelles, sans données fictives.</p></div><span className="panel-icon">⌁</span></div>
    {serviceRow("↗","API REST","Health check",status?.api?.ok)}
    {serviceRow("▦","Cloudflare D1","Base et schéma",status?.d1?.ok)}
    {serviceRow("♙","Cloudflare Access","Protection de la console",authMode==="Cloudflare Access")}
   </section>
   <section className="admin-panel"><div className="panel-title"><div><h2>Modules d’administration</h2><p>Disponibilité affichée honnêtement, sans simuler de fonctionnalités.</p></div></div><div className="module-grid">{modules.map(([n,d])=><article className="module-card" key={n}><span>◇</span><b>{n}</b><small>{d}</small><em>À finaliser</em></article>)}</div></section>
   <footer>GeStock Admin · Diagnostic {status?.checkedAt?new Date(status.checkedAt).toLocaleString("fr-FR"):"en attente"}</footer>
  </main>
 </div>;
}
