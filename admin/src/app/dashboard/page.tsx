"use client";
import { useEffect, useState } from "react";

type Health = { ok?: boolean; service?: string; version?: string; database?: string; table_count?: number };
type Status = { api: Health | null; d1: Health | null; checkedAt: string; errors: string[] };
type Overview = { users: number; businesses: number; active_businesses: number; products: number; sales: number; stock_movements: number; sync_pending: number; sync_conflicts: number };
type Business = { id: string; name: string; business_type: string; country_code: string; currency_code: string; status: string; created_at?: string; members: number; products: number; sales: number; revenue: number };
type AdminUser = { id: string; email?: string | null; display_name?: string | null; status?: string; created_at?: string | null; active_businesses: number; organizations: number; devices: number; last_seen?: string | null };
type AdminSale = { id: string; sale_number: string; business_id: string; business_name?: string; currency_code: string; total: number; amount_paid: number; status: string; sold_at?: string; payment_method?: string; payment_status?: string };
type SyncOperation = { id: string; business_name?: string; entity_type: string; entity_id?: string; operation_type: string; status: string; created_at?: string; processed_at?: string; platform?: string; actor_email?: string };
type SyncData = { summary: Record<string, number>; operations: SyncOperation[] };
type LowStockItem = { business_name?: string; product_name: string; sku?: string; warehouse_name?: string; quantity: number; min_quantity: number; sale_price: number; currency_code: string };
type InventoryData = { data: LowStockItem[]; count: number; capped?: boolean };
type AdminProduct = { id: string; business_id: string; business_name?: string; name: string; sku?: string | null; barcode?: string | null; unit: string; purchase_price: number; sale_price: number; tax_rate: number; is_active: number; track_stock: number; min_quantity: number; quantity: number; warehouse_name?: string; currency_code: string; updated_at?: string };
type ProductsData = { data: AdminProduct[]; count: number; capped?: boolean };
type AdminMovement = { id: string; business_name?: string; currency_code?: string; product_name?: string; sku?: string; warehouse_name?: string; movement_type: string; quantity_delta: number; unit_cost?: number | null; source_type?: string; source_id?: string; note?: string; actor_email?: string; occurred_at?: string };
type MovementsData = { data: AdminMovement[]; count: number; capped?: boolean };
type SupportTicket = {id:string;email?:string;display_name?:string;business_name?:string;subject:string;message:string;status:string;priority:string;admin_reply?:string|null;created_at:string};
type Subscription = {business_id:string;business_name:string;currency_code:string;plan_code:string;status:string;started_at:string;ends_at?:string|null};
type AdSetting = {placement_key:string;enabled:number;provider:string;ad_unit_id?:string|null;frequency_cap:number};
type AuditEntry = {id:string;actor_email:string;action:string;entity_type:string;entity_id?:string;created_at:string};
const ADMIN_EMAIL = "editadigoun@gmail.com";
const capabilities = [
  { name: "Catalogue et stock", detail: "Recherche globale du catalogue, niveaux et journal des mouvements (lecture seule)", state: "Connecté" },
  { name: "Ventes / POS", detail: "Ventes, lignes, paiements et déduction de stock", state: "Connecté" },
  { name: "Synchronisation mobile", detail: "Appareils, opérations idempotentes et conflits", state: "Connecté" },
  { name: "Entreprises", detail: "Liste et métriques réelles (lecture seule)", state: "Connecté" },
  { name: "Annuaire utilisateurs", detail: "Comptes, entreprises, organisations et appareils (lecture seule)", state: "Connecté" },
  { name: "Gestion utilisateurs / rôles", detail: "CRUD, invitations et permissions détaillées", state: "Backend manquant" },
  { name: "Abonnements / facturation", detail: "Plans, paiements et droits", state: "Backend manquant" },
  { name: "Publicités / monétisation", detail: "Campagnes, placements et revenus", state: "Backend manquant" },
  { name: "Support / tickets", detail: "Workflow de support", state: "Backend manquant" },
  { name: "Paramètres / audit", detail: "Configuration globale et journal consultable", state: "Backend manquant" },
];
function number(value?: number) { return new Intl.NumberFormat("fr-FR").format(value ?? 0); }
function money(value: number, currency: string) { return new Intl.NumberFormat("fr-FR", { maximumFractionDigits: 2 }).format(value ?? 0) + " " + currency; }
function date(value?: string) { return value ? new Date(value).toLocaleString("fr-FR", { dateStyle: "short", timeStyle: "short" }) : "—"; }
function statusLabel(value?: string) { return ({ queued: "En attente", applied: "Appliquée", conflict: "Conflit", rejected: "Rejetée", failed: "Échec", processing: "En cours", completed: "Terminée", pending: "En attente" } as Record<string, string>)[value || ""] || value || "—"; }
export default function Dashboard() {
  const [email, setEmail] = useState("");
  const [authMode, setAuthMode] = useState("");
  const [status, setStatus] = useState<Status | null>(null);
  const [overview, setOverview] = useState<Overview | null>(null);
  const [businesses, setBusinesses] = useState<Business[]>([]);
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [userQuery, setUserQuery] = useState("");
  const [sales, setSales] = useState<AdminSale[]>([]);
  const [syncData, setSyncData] = useState<SyncData | null>(null);
  const [inventory, setInventory] = useState<InventoryData | null>(null);
  const [productsData, setProductsData] = useState<ProductsData | null>(null);
  const [productQuery, setProductQuery] = useState("");
  const [movementsData, setMovementsData] = useState<MovementsData | null>(null);
  const [movementQuery, setMovementQuery] = useState("");
  const [tickets,setTickets]=useState<SupportTicket[]>([]);
  const [subscriptions,setSubscriptions]=useState<Subscription[]>([]);
  const [adSettings,setAdSettings]=useState<AdSetting[]>([]);
  const [auditEntries,setAuditEntries]=useState<AuditEntry[]>([]);
  const [selectedBusiness,setSelectedBusiness]=useState("");
  const [planCode,setPlanCode]=useState("free");
  const [subscriptionStatus,setSubscriptionStatus]=useState("active");
  const [settingKey,setSettingKey]=useState("");
  const [settingJson,setSettingJson]=useState("{}");
  const [errors, setErrors] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);

  async function refresh() {
    setLoading(true);
    const [healthResult, overviewResult, businessResult, userResult, salesResult, syncResult, inventoryResult, productsResult, movementsResult, ticketResult, subscriptionResult, adResult, auditResult] = await Promise.allSettled([
      fetch("/api/status", { cache: "no-store" }).then((r) => r.json()),
      fetch("/api/admin/overview", { cache: "no-store" }).then(async (r) => ({ ok: r.ok, body: await r.json() })),
      fetch("/api/admin/businesses", { cache: "no-store" }).then(async (r) => ({ ok: r.ok, body: await r.json() })),
      fetch(`/api/admin/users?q=${encodeURIComponent(userQuery)}`, { cache: "no-store" }).then(async (r) => ({ ok: r.ok, body: await r.json() })),
      fetch("/api/admin/sales", { cache: "no-store" }).then(async (r) => ({ ok: r.ok, body: await r.json() })),
      fetch("/api/admin/sync", { cache: "no-store" }).then(async (r) => ({ ok: r.ok, body: await r.json() })),
      fetch("/api/admin/inventory", { cache: "no-store" }).then(async (r) => ({ ok: r.ok, body: await r.json() })),
      fetch(`/api/admin/products?q=${encodeURIComponent(productQuery)}`, { cache: "no-store" }).then(async (r) => ({ ok: r.ok, body: await r.json() })),
      fetch(`/api/admin/movements?q=${encodeURIComponent(movementQuery)}`, { cache: "no-store" }).then(async (r) => ({ ok: r.ok, body: await r.json() })),
      fetch("/api/admin/support",{cache:"no-store"}).then(async r=>({ok:r.ok,body:await r.json()})),
      fetch("/api/admin/subscriptions",{cache:"no-store"}).then(async r=>({ok:r.ok,body:await r.json()})),
      fetch("/api/admin/ads",{cache:"no-store"}).then(async r=>({ok:r.ok,body:await r.json()})),
      fetch("/api/admin/audit?limit=100",{cache:"no-store"}).then(async r=>({ok:r.ok,body:await r.json()})),
    ]);
    const nextErrors: string[] = [];
    if (healthResult.status === "fulfilled") setStatus(healthResult.value as Status);
    else nextErrors.push("Diagnostic des services indisponible.");
    if (overviewResult.status === "fulfilled" && overviewResult.value.ok) setOverview(overviewResult.value.body?.data ?? null);
    else { setOverview(null); nextErrors.push("Les métriques admin ne sont pas accessibles (session ou API)."); }
    if (businessResult.status === "fulfilled" && businessResult.value.ok) setBusinesses(businessResult.value.body?.data ?? []);
    else { setBusinesses([]); nextErrors.push("La liste des entreprises n’est pas accessible."); }
    if (userResult.status === "fulfilled" && userResult.value.ok) setUsers(userResult.value.body?.data ?? []);
    else { setUsers([]); nextErrors.push("L’annuaire utilisateurs n’est pas accessible."); }
    if (salesResult.status === "fulfilled" && salesResult.value.ok) setSales(salesResult.value.body?.data ?? []);
    else { setSales([]); nextErrors.push("L’historique des ventes admin n’est pas accessible."); }
    if (syncResult.status === "fulfilled" && syncResult.value.ok) setSyncData(syncResult.value.body?.data ?? null);
    else { setSyncData(null); nextErrors.push("Le suivi des synchronisations n’est pas accessible."); }
    if (inventoryResult.status === "fulfilled" && inventoryResult.value.ok) setInventory(inventoryResult.value.body ?? null);
    else { setInventory(null); nextErrors.push("Le rapport de stock bas n’est pas accessible."); }
    if (productsResult.status === "fulfilled" && productsResult.value.ok) setProductsData(productsResult.value.body ?? null);
    else { setProductsData(null); nextErrors.push("Le catalogue global n’est pas accessible."); }
    if (movementsResult.status === "fulfilled" && movementsResult.value.ok) setMovementsData(movementsResult.value.body ?? null);
    else { setMovementsData(null); nextErrors.push("Le journal global des mouvements n’est pas accessible."); }
    if(ticketResult.status==="fulfilled"&&ticketResult.value.ok)setTickets(ticketResult.value.body?.data??[]);else{setTickets([]);nextErrors.push("Les tickets support ne sont pas accessibles.");}
    if(subscriptionResult.status==="fulfilled"&&subscriptionResult.value.ok)setSubscriptions(subscriptionResult.value.body?.data??[]);else{setSubscriptions([]);nextErrors.push("Les abonnements ne sont pas accessibles.");}
    if(adResult.status==="fulfilled"&&adResult.value.ok)setAdSettings(adResult.value.body?.data??[]);else{setAdSettings([]);nextErrors.push("Les paramètres publicitaires ne sont pas accessibles.");}
    if(auditResult.status==="fulfilled"&&auditResult.value.ok)setAuditEntries(auditResult.value.body?.data??[]);else{setAuditEntries([]);nextErrors.push("Le journal d’audit n’est pas accessible.");}
    setErrors(nextErrors);
    setLoading(false);
  }

  useEffect(() => {
    let live = true;
    (async () => {
      try {
        const access = await fetch("/api/access/identity", { cache: "no-store" }).then((r) => r.ok ? r.json() : null);
        const accessEmail = (access?.email || "").toLowerCase();
        if (accessEmail && accessEmail !== ADMIN_EMAIL) { location.replace("/login"); return; }
        if (accessEmail !== ADMIN_EMAIL) { location.replace("/login"); return; }
        if (live) { setEmail(ADMIN_EMAIL); setAuthMode("Cloudflare Access"); }
        if (live) await refresh();
      } catch { location.replace("/login"); }
    })();
    return () => { live = false; };
  }, []);

  async function logout() {
    location.href = "/cdn-cgi/access/logout";
  }
  async function adminAction(url:string,method:string,body:unknown){
    try{const response=await fetch(url,{method,headers:{"Content-Type":"application/json"},body:JSON.stringify(body)});const data=await response.json().catch(()=>({}));if(!response.ok)throw new Error(data?.message||data?.error||"Action refusée");await refresh();return true;}catch(e){alert(e instanceof Error?e.message:"Action impossible");return false;}
  }
  const serviceRow = (symbol: string, name: string, detail: string, available?: boolean) => (
    <div className="service-row" key={name}>
      <div className="service-icon">{symbol}</div><div className="service-copy"><b>{name}</b><small>{detail}</small></div>
      <span className={"service-state " + (available === undefined ? "pending" : available ? "good" : "bad")}>{loading ? "En cours" : available === undefined ? "À vérifier" : available ? "Disponible" : "Échec"}</span>
    </div>
  );
  const metric = (label: string, value: number | undefined, detail: string) => (
    <article className="metric-card" key={label}><small>{label}</small><strong>{value === undefined ? "—" : number(value)}</strong><p>{detail}</p></article>
  );

  return <div className="admin-shell">
    <aside className="admin-sidebar"><div className="admin-brand"><span className="brand-mark">G</span><div><b>GeStock</b><small>ADMIN CONTROL</small></div></div>
      <div className="sidebar-label">PILOTAGE</div><a className="sidebar-link active" href="/dashboard">◈ &nbsp; Vue générale</a>
      <div className="sidebar-label">PLATEFORME</div><div className="sidebar-module"><span>◇</span><div><b>Entreprises</b><small>Lecture des données réelles</small></div></div>
      <div className="sidebar-module"><span>◇</span><div><b>Services</b><small>API, D1 et synchronisation</small></div></div>
      <div className="sidebar-module"><span>◇</span><div><b>Opérations</b><small>Ventes, stocks et sync</small></div></div>
      <div className="admin-profile"><b>Administrateur</b><small>{email}</small><button onClick={logout}>Déconnexion</button></div>
    </aside>
    <main className="admin-main"><header className="admin-topbar"><span>GeStock <span className="crumb">/</span> Console</span><div className="admin-top-right"><span className="session-pill">{authMode || "Session"}</span><span className="online-dot">●</span></div></header>
      <section className="admin-welcome"><div><small>CONSOLE DE PILOTAGE</small><h1>Bonjour, administrateur.</h1><p>Fonctionnalités connectées aux données réelles. Les modules non développés sont explicitement signalés.</p></div><button className="refresh" onClick={refresh} disabled={loading}>{loading ? "Vérification…" : "↻ Actualiser"}</button></section>
      {errors.length > 0 && <section className="admin-alert">{errors.map((error) => <p key={error}>{error}</p>)}</section>}
      <section className="metric-grid">
        {metric("Utilisateurs", overview?.users, "Comptes présents dans D1")}
        {metric("Entreprises actives", overview?.active_businesses, "Espaces actifs")}
        {metric("Produits", overview?.products, "Catalogue total")}
        {metric("Ventes", overview?.sales, "Transactions enregistrées")}
        {metric("Mouvements de stock", overview?.stock_movements, "Journal total")}
        {metric("Sync en attente", overview?.sync_pending, "Opérations queued")}
        {metric("Conflits sync", overview?.sync_conflicts, "À examiner")}
        {metric("Stocks faibles", inventory?.count, "Seuil d’alerte réel")}
      </section>
      <section className="admin-panel"><div className="panel-title"><div><h2>Annuaire utilisateurs</h2><p>Comptes réels D1 — lecture seule, maximum 100 résultats.</p></div><span className="panel-icon">♙</span></div>
        <div style={{display:"flex",gap:8,flexWrap:"wrap",alignItems:"center",marginBottom:12}}><input aria-label="Rechercher un utilisateur" placeholder="Email ou nom…" value={userQuery} onChange={(e)=>setUserQuery(e.target.value)} style={{flex:"1 1 220px",minWidth:180,padding:"10px 12px",border:"1px solid var(--border, #d8dde5)",borderRadius:8,background:"var(--surface, #fff)",color:"inherit"}}/><button className="refresh" onClick={refresh} disabled={loading}>Rechercher</button><small>{number(users.length)} résultat(s)</small></div>
        {users.length === 0 ? <p className="empty-state">{loading ? "Chargement…" : "Aucun utilisateur enregistré correspondant."}</p> : <div className="table-scroll"><table className="business-table"><thead><tr><th>Utilisateur</th><th>Créé le</th><th>Entreprises</th><th>Organisations</th><th>Appareils</th><th>Dernière activité sync</th><th>Statut</th><th>Action</th></tr></thead><tbody>{users.map((user) => <tr key={user.id}><td><b>{user.display_name || "Nom non renseigné"}</b><small>{user.email || "Email non renseigné"} · {user.id.slice(0,8)}</small></td><td>{date(user.created_at || undefined)}</td><td>{number(user.active_businesses)}</td><td>{number(user.organizations)}</td><td>{number(user.devices)}</td><td>{date(user.last_seen || undefined)}</td><td><span className={"business-status "+(user.status==="suspended"?"inactive":"active")}>{user.status||"active"}</span></td><td><button className="refresh" onClick={()=>adminAction("/api/admin/users/"+user.id,"PATCH",{status:user.status==="suspended"?"active":"suspended"})}>{user.status==="suspended"?"Réactiver":"Suspendre"}</button></td></tr>)}</tbody></table></div>}
      </section>
      <section className="admin-panel"><div className="panel-title"><div><h2>Entreprises enregistrées</h2><p>Liste backend — lecture seule, sans données inventées.</p></div><span className="panel-icon">▦</span></div>
        {businesses.length === 0 ? <p className="empty-state">{loading ? "Chargement…" : "Aucune entreprise enregistrée dans D1."}</p> : <div className="table-scroll"><table className="business-table"><thead><tr><th>Entreprise</th><th>Type / pays</th><th>Membres</th><th>Produits</th><th>Ventes</th><th>Revenu</th><th>Statut</th><th>Action</th></tr></thead><tbody>{businesses.map((business) => <tr key={business.id}><td><b>{business.name}</b><small>{business.id.slice(0, 8)}</small></td><td>{business.business_type}<small>{business.country_code} · {business.currency_code}</small></td><td>{number(business.members)}</td><td>{number(business.products)}</td><td>{number(business.sales)}</td><td>{money(business.revenue, business.currency_code)}</td><td><span className={"business-status " + (business.status === "active" ? "active" : "inactive")}>{business.status}</span></td><td><button className="refresh" onClick={()=>adminAction("/api/admin/businesses/"+business.id+"/status","PATCH",{status:business.status==="suspended"?"active":"suspended"})}>{business.status==="suspended"?"Réactiver":"Suspendre"}</button></td></tr>)}</tbody></table></div>}
      </section>
      <section className="admin-panel"><div className="panel-title"><div><h2>Ventes récentes</h2><p>50 dernières transactions réelles, sans action de modification.</p></div><span className="panel-icon">€</span></div>
        {sales.length === 0 ? <p className="empty-state">{loading ? "Chargement…" : "Aucune vente dans D1."}</p> : <div className="table-scroll"><table className="business-table"><thead><tr><th>Date</th><th>Entreprise</th><th>Référence</th><th>Paiement</th><th>Montant</th><th>État</th></tr></thead><tbody>{sales.map((sale) => <tr key={sale.id}><td>{date(sale.sold_at)}</td><td>{sale.business_name || sale.business_id.slice(0,8)}</td><td>{sale.sale_number}</td><td>{sale.payment_method || "—"}<small>{statusLabel(sale.payment_status)}</small></td><td>{money(sale.total, sale.currency_code)}</td><td><span className={"business-status " + (sale.status === "completed" ? "active" : "inactive")}>{statusLabel(sale.status)}</span></td></tr>)}</tbody></table></div>}
      </section>
      <section className="admin-panel"><div className="panel-title"><div><h2>Stocks sous seuil</h2><p>Inventaire du dépôt principal — quantités comparées au seuil produit.</p></div><span className="panel-icon">▤</span></div>
        {!inventory?.data?.length ? <p className="empty-state">{loading ? "Chargement…" : "Aucun produit sous son seuil de stock."}</p> : <div className="table-scroll"><table className="business-table"><thead><tr><th>Entreprise</th><th>Produit</th><th>Référence</th><th>Stock</th><th>Seuil</th><th>Prix</th></tr></thead><tbody>{inventory.data.map((item, i) => <tr key={item.product_name + "-" + i}><td>{item.business_name || "—"}</td><td><b>{item.product_name}</b><small>{item.warehouse_name || "Dépôt non défini"}</small></td><td>{item.sku || "—"}</td><td><span className="stock-warning">{number(item.quantity)}</span></td><td>{number(item.min_quantity)}</td><td>{money(item.sale_price, item.currency_code)}</td></tr>)}</tbody></table></div>}
        {inventory?.capped && <p className="table-note">Affichage limité à 100 produits; total calculé: {number(inventory.count)}.</p>}
      </section>
      <section className="admin-panel"><div className="panel-title"><div><h2>Catalogue global</h2><p>Recherche dans les produits réels de toutes les entreprises · lecture seule · 100 résultats max.</p></div><span className="panel-icon">▣</span></div>
        <div style={{display:"flex",gap:8,flexWrap:"wrap",alignItems:"center",marginBottom:12}}><input aria-label="Rechercher dans le catalogue" placeholder="Nom, SKU, code-barres ou entreprise…" value={productQuery} onChange={(e)=>setProductQuery(e.target.value)} style={{flex:"1 1 260px",minWidth:180,padding:"10px 12px",border:"1px solid var(--border, #d8dde5)",borderRadius:8,background:"var(--surface, #fff)",color:"inherit"}}/><button className="refresh" onClick={refresh} disabled={loading}>Rechercher</button><small>{number(productsData?.count)} produit(s)</small></div>
        {!productsData?.data?.length ? <p className="empty-state">{loading ? "Chargement…" : "Aucun produit correspondant dans D1."}</p> : <div className="table-scroll"><table className="business-table"><thead><tr><th>Entreprise</th><th>Produit</th><th>Référence / code-barres</th><th>Stock</th><th>Seuil</th><th>Prix achat</th><th>Prix vente</th><th>État</th></tr></thead><tbody>{productsData.data.map((product)=><tr key={product.id}><td>{product.business_name || product.business_id.slice(0,8)}<small>{product.currency_code}</small></td><td><b>{product.name}</b><small>{product.unit}</small></td><td>{product.sku || "—"}<small>{product.barcode || "—"}</small></td><td>{product.track_stock ? number(product.quantity) : "Non suivi"}</td><td>{product.track_stock ? number(product.min_quantity) : "—"}</td><td>{money(product.purchase_price,product.currency_code)}</td><td>{money(product.sale_price,product.currency_code)}</td><td><span className={"business-status "+(product.is_active ? "active" : "inactive")}>{product.is_active ? "Actif" : "Inactif"}</span></td></tr>)}</tbody></table></div>}
        {productsData?.capped && <p className="table-note">Affichage limité à 100 produits; total calculé: {number(productsData.count)}.</p>}
      </section>
      <section className="admin-panel"><div className="panel-title"><div><h2>Journal global des mouvements</h2><p>Historique réel des entrées, sorties, ventes et ajustements · lecture seule · 100 résultats max.</p></div><span className="panel-icon">⇄</span></div>
        <div style={{display:"flex",gap:8,flexWrap:"wrap",alignItems:"center",marginBottom:12}}><input aria-label="Rechercher les mouvements" placeholder="Produit, entreprise, motif ou utilisateur…" value={movementQuery} onChange={(e)=>setMovementQuery(e.target.value)} style={{flex:"1 1 260px",minWidth:180,padding:"10px 12px",border:"1px solid var(--border, #d8dde5)",borderRadius:8,background:"var(--surface, #fff)",color:"inherit"}}/><button className="refresh" onClick={refresh} disabled={loading}>Rechercher</button><small>{number(movementsData?.count)} mouvement(s)</small></div>
        {!movementsData?.data?.length ? <p className="empty-state">{loading ? "Chargement…" : "Aucun mouvement enregistré dans D1."}</p> : <div className="table-scroll"><table className="business-table"><thead><tr><th>Date</th><th>Entreprise</th><th>Produit / dépôt</th><th>Type</th><th>Variation</th><th>Coût unitaire</th><th>Origine</th><th>Utilisateur / motif</th></tr></thead><tbody>{movementsData.data.map((movement)=><tr key={movement.id}><td>{date(movement.occurred_at)}</td><td>{movement.business_name || "—"}</td><td><b>{movement.product_name || "Produit supprimé"}</b><small>{movement.sku || "—"} · {movement.warehouse_name || "Dépôt"}</small></td><td>{movement.movement_type}</td><td><span className={movement.quantity_delta >= 0 ? "business-status active" : "business-status inactive"}>{movement.quantity_delta > 0 ? "+" : ""}{number(movement.quantity_delta)}</span></td><td>{movement.unit_cost == null ? "—" : money(movement.unit_cost,movement.currency_code || "XOF")}</td><td>{movement.source_type || "Manuel"}<small>{movement.source_id?.slice(0,8) || "—"}</small></td><td>{movement.actor_email || "—"}<small>{movement.note || "—"}</small></td></tr>)}</tbody></table></div>}
        {movementsData?.capped && <p className="table-note">Affichage limité à 100 mouvements; total calculé: {number(movementsData.count)}.</p>}
      </section>
      <section className="admin-panel"><div className="panel-title"><div><h2>Synchronisation mobile</h2><p>État des opérations côté serveur et derniers appareils observés.</p></div><span className="panel-icon">↻</span></div>
        <div className="sync-summary">{["queued","applied","conflict","rejected","failed","processing"].map((key) => <div className="sync-count" key={key}><small>{statusLabel(key)}</small><b>{number(syncData?.summary?.[key])}</b></div>)}</div>
        {!syncData?.operations?.length ? <p className="empty-state">{loading ? "Chargement…" : "Aucune opération de synchronisation enregistrée."}</p> : <div className="table-scroll"><table className="business-table"><thead><tr><th>Reçue</th><th>Entreprise</th><th>Type</th><th>Opération</th><th>Appareil</th><th>Utilisateur</th><th>État</th></tr></thead><tbody>{syncData.operations.map((op) => <tr key={op.id}><td>{date(op.created_at)}</td><td>{op.business_name || "—"}</td><td>{op.entity_type}</td><td>{op.operation_type}<small>{op.entity_id?.slice(0,8) || "—"}</small></td><td>{op.platform || "—"}</td><td>{op.actor_email || "—"}</td><td><span className={"business-status " + (op.status === "applied" ? "active" : "inactive")}>{statusLabel(op.status)}</span></td></tr>)}</tbody></table></div>}
      </section>
      <section className="admin-panel"><div className="panel-title"><div><h2>État des services</h2><p>Health checks réellement exécutés.</p></div><span className="panel-icon">⌁</span></div>
        {serviceRow("↗", "API GeStock", "Health check", status?.api?.ok)}
        {serviceRow("▦", "Cloudflare D1", "Base et schéma", status?.d1?.ok)}
        {serviceRow("♙", "Cloudflare Access", "Protection edge vérifiée au déploiement", authMode.includes("Cloudflare Access"))}
      </section>
      <section className="admin-panel"><div className="panel-title"><div><h2>Support utilisateurs</h2><p>Tickets, réponses et suivi du traitement.</p></div><span className="panel-icon">✉</span></div>
        {!tickets.length?<p className="empty-state">{loading?"Chargement…":"Aucun ticket support."}</p>:<div className="table-scroll"><table className="business-table"><thead><tr><th>Date</th><th>Utilisateur</th><th>Entreprise</th><th>Demande</th><th>État</th><th>Réponse admin</th><th>Action</th></tr></thead><tbody>{tickets.map(t=><tr key={t.id}><td>{date(t.created_at)}</td><td>{t.display_name||"—"}<small>{t.email||"—"}</small></td><td>{t.business_name||"—"}</td><td><b>{t.subject}</b><small>{t.message}</small></td><td><select defaultValue={t.status} id={"ticket-status-"+t.id}><option value="open">Ouvert</option><option value="in_progress">En cours</option><option value="resolved">Résolu</option><option value="closed">Fermé</option></select></td><td><textarea defaultValue={t.admin_reply||""} id={"ticket-reply-"+t.id} rows={2} style={{minWidth:180}}/></td><td><button className="refresh" onClick={()=>adminAction("/api/admin/support/"+t.id,"PATCH",{status:(document.getElementById("ticket-status-"+t.id) as HTMLSelectElement)?.value,admin_reply:(document.getElementById("ticket-reply-"+t.id) as HTMLTextAreaElement)?.value})}>Enregistrer</button></td></tr>)}</tbody></table></div>}
      </section>
      <section className="admin-panel"><div className="panel-title"><div><h2>Abonnements</h2><p>Configuration des droits par entreprise; aucun paiement externe n’est déclenché.</p></div><span className="panel-icon">◇</span></div>
        <div style={{display:"flex",gap:8,flexWrap:"wrap",marginBottom:14}}><select value={selectedBusiness} onChange={e=>setSelectedBusiness(e.target.value)}><option value="">Choisir une entreprise…</option>{businesses.map(b=><option key={b.id} value={b.id}>{b.name}</option>}</select><select value={planCode} onChange={e=>setPlanCode(e.target.value)}><option value="free">Free</option><option value="plus">Plus</option><option value="pro">Pro</option><option value="business">Business</option></select><select value={subscriptionStatus} onChange={e=>setSubscriptionStatus(e.target.value)}><option value="active">Actif</option><option value="trial">Essai</option><option value="past_due">En retard</option><option value="cancelled">Annulé</option><option value="expired">Expiré</option></select><button className="refresh" disabled={!selectedBusiness} onClick={()=>adminAction("/api/admin/subscriptions/"+selectedBusiness,"PUT",{plan_code:planCode,status:subscriptionStatus})}>Attribuer</button></div>
        {!subscriptions.length?<p className="empty-state">Aucun abonnement configuré.</p>:<div className="table-scroll"><table className="business-table"><thead><tr><th>Entreprise</th><th>Plan</th><th>État</th><th>Début</th><th>Fin</th></tr></thead><tbody>{subscriptions.map(s=><tr key={s.business_id}><td>{s.business_name}</td><td>{s.plan_code}</td><td>{s.status}</td><td>{date(s.started_at)}</td><td>{date(s.ends_at||undefined)}</td></tr>)}</tbody></table></div>}
      </section>
      <section className="admin-panel"><div className="panel-title"><div><h2>Monétisation publicitaire</h2><p>Paramètres de placements; l’activation réelle nécessite les identifiants de fournisseur et les SDK mobiles.</p></div><span className="panel-icon">◉</span></div>
        <div style={{display:"flex",gap:8,flexWrap:"wrap",marginBottom:12}}><input id="new-placement" placeholder="Placement (ex. home_banner)" /><input id="new-ad-unit" placeholder="ID unité publicitaire" /><button className="refresh" onClick={()=>adminAction("/api/admin/ads/"+((document.getElementById("new-placement") as HTMLInputElement)?.value||""),"PUT",{enabled:true,provider:"admob",ad_unit_id:(document.getElementById("new-ad-unit") as HTMLInputElement)?.value||null,frequency_cap:0})}>Ajouter / activer</button></div>
        {!adSettings.length?<p className="empty-state">Aucun placement configuré.</p>:<div className="table-scroll"><table className="business-table"><thead><tr><th>Placement</th><th>Fournisseur</th><th>Unit ID</th><th>État</th><th>Cap</th><th>Action</th></tr></thead><tbody>{adSettings.map(a=><tr key={a.placement_key}><td>{a.placement_key}</td><td>{a.provider}</td><td>{a.ad_unit_id||"—"}</td><td>{a.enabled?"Activé":"Désactivé"}</td><td>{a.frequency_cap}</td><td><button className="refresh" onClick={()=>adminAction("/api/admin/ads/"+a.placement_key,"PUT",{enabled:!a.enabled,provider:a.provider,ad_unit_id:a.ad_unit_id,frequency_cap:a.frequency_cap})}>{a.enabled?"Désactiver":"Activer"}</button></td></tr>)}</tbody></table></div>}
      </section>
      <section className="admin-panel"><div className="panel-title"><div><h2>Paramètres plateforme</h2><p>Clé/valeur JSON pour configuration globale et future intégration des droits.</p></div><span className="panel-icon">⚙</span></div>
        <div style={{display:"flex",gap:8,flexWrap:"wrap",alignItems:"flex-start"}}><input value={settingKey} onChange={e=>setSettingKey(e.target.value)} placeholder="Clé (ex. feature_flags)" /><textarea value={settingJson} onChange={e=>setSettingJson(e.target.value)} rows={3} placeholder="Valeur JSON"/><button className="refresh" onClick={()=>{try{const value=JSON.parse(settingJson);adminAction("/api/admin/settings/"+encodeURIComponent(settingKey),"PUT",value);}catch{alert("JSON invalide");}}}>Enregistrer</button></div>
      </section>
      <section className="admin-panel"><div className="panel-title"><div><h2>Journal d’audit plateforme</h2><p>Historique des actions administratives.</p></div><span className="panel-icon">▤</span></div>
        {!auditEntries.length?<p className="empty-state">Aucune action administrative enregistrée.</p>:<div className="table-scroll"><table className="business-table"><thead><tr><th>Date</th><th>Administrateur</th><th>Action</th><th>Entité</th><th>ID</th></tr></thead><tbody>{auditEntries.map(a=><tr key={a.id}><td>{date(a.created_at)}</td><td>{a.actor_email}</td><td>{a.action}</td><td>{a.entity_type}</td><td>{a.entity_id||"—"}</td></tr>)}</tbody></table></div>}
      </section>
      <section className="admin-panel"><div className="panel-title"><div><h2>Fonctionnalités</h2><p>État du backend : connectées ou non implémentées.</p></div></div><div className="capability-list">{capabilities.map((item) => <article className="capability" key={item.name}><div><b>{item.name}</b><small>{item.detail}</small></div><span className={item.state === "Connecté" ? "cap-ready" : "cap-missing"}>{item.state}</span></article>)}</div></section>
      <footer>GeStock Admin · {status?.checkedAt ? new Date(status.checkedAt).toLocaleString("fr-FR") : "diagnostic en attente"}</footer>
    </main>
  </div>;
}
