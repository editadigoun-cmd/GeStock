"use client";
import { useEffect, useState } from "react";

type Health = { ok?: boolean; service?: string; version?: string; database?: string; table_count?: number };
type Status = { api: Health | null; d1: Health | null; checkedAt: string; errors: string[] };
type Overview = { users: number; businesses: number; active_businesses: number; products: number; sales: number; stock_movements: number; sync_pending: number; sync_conflicts: number };
type Business = { id: string; name: string; business_type: string; country_code: string; currency_code: string; status: string; created_at?: string; members: number; products: number; sales: number; revenue: number };
type AdminSale = { id: string; sale_number: string; business_id: string; business_name?: string; currency_code: string; total: number; amount_paid: number; status: string; sold_at?: string; payment_method?: string; payment_status?: string };
type SyncOperation = { id: string; business_name?: string; entity_type: string; entity_id?: string; operation_type: string; status: string; created_at?: string; processed_at?: string; platform?: string; actor_email?: string };
type SyncData = { summary: Record<string, number>; operations: SyncOperation[] };
type LowStockItem = { business_name?: string; product_name: string; sku?: string; warehouse_name?: string; quantity: number; min_quantity: number; sale_price: number; currency_code: string };
type InventoryData = { data: LowStockItem[]; count: number; capped?: boolean };
const ADMIN_EMAIL = "editadigoun@gmail.com";
const capabilities = [
  { name: "Catalogue et stock", detail: "Produits, niveaux et journal des mouvements", state: "Connecté" },
  { name: "Ventes / POS", detail: "Ventes, lignes, paiements et déduction de stock", state: "Connecté" },
  { name: "Synchronisation mobile", detail: "Appareils, opérations idempotentes et conflits", state: "Connecté" },
  { name: "Entreprises", detail: "Liste et métriques réelles (lecture seule)", state: "Connecté" },
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
  const [sales, setSales] = useState<AdminSale[]>([]);
  const [syncData, setSyncData] = useState<SyncData | null>(null);
  const [inventory, setInventory] = useState<InventoryData | null>(null);
  const [errors, setErrors] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);

  async function refresh() {
    setLoading(true);
    const [healthResult, overviewResult, businessResult, salesResult, syncResult, inventoryResult] = await Promise.allSettled([
      fetch("/api/status", { cache: "no-store" }).then((r) => r.json()),
      fetch("/api/admin/overview", { cache: "no-store" }).then(async (r) => ({ ok: r.ok, body: await r.json() })),
      fetch("/api/admin/businesses", { cache: "no-store" }).then(async (r) => ({ ok: r.ok, body: await r.json() })),
      fetch("/api/admin/sales", { cache: "no-store" }).then(async (r) => ({ ok: r.ok, body: await r.json() })),
      fetch("/api/admin/sync", { cache: "no-store" }).then(async (r) => ({ ok: r.ok, body: await r.json() })),
      fetch("/api/admin/inventory", { cache: "no-store" }).then(async (r) => ({ ok: r.ok, body: await r.json() })),
    ]);
    const nextErrors: string[] = [];
    if (healthResult.status === "fulfilled") setStatus(healthResult.value as Status);
    else nextErrors.push("Diagnostic des services indisponible.");
    if (overviewResult.status === "fulfilled" && overviewResult.value.ok) setOverview(overviewResult.value.body?.data ?? null);
    else { setOverview(null); nextErrors.push("Les métriques admin ne sont pas accessibles (session ou API)."); }
    if (businessResult.status === "fulfilled" && businessResult.value.ok) setBusinesses(businessResult.value.body?.data ?? []);
    else { setBusinesses([]); nextErrors.push("La liste des entreprises n’est pas accessible."); }
    if (salesResult.status === "fulfilled" && salesResult.value.ok) setSales(salesResult.value.body?.data ?? []);
    else { setSales([]); nextErrors.push("L’historique des ventes admin n’est pas accessible."); }
    if (syncResult.status === "fulfilled" && syncResult.value.ok) setSyncData(syncResult.value.body?.data ?? null);
    else { setSyncData(null); nextErrors.push("Le suivi des synchronisations n’est pas accessible."); }
    if (inventoryResult.status === "fulfilled" && inventoryResult.value.ok) setInventory(inventoryResult.value.body ?? null);
    else { setInventory(null); nextErrors.push("Le rapport de stock bas n’est pas accessible."); }
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
        const session = await fetch("/api/auth/get-session", { credentials: "include", cache: "no-store" }).then((r) => r.ok ? r.json() : null);
        if ((session?.user?.email || "").toLowerCase() !== ADMIN_EMAIL) { location.replace("/login"); return; }
        if (live) { setEmail(ADMIN_EMAIL); setAuthMode(accessEmail === ADMIN_EMAIL ? "Cloudflare Access + Neon Auth" : "Neon Auth"); }
        if (live) await refresh();
      } catch { location.replace("/login"); }
    })();
    return () => { live = false; };
  }, []);

  async function logout() {
    await fetch("/api/auth/sign-out", { method: "POST", credentials: "include" });
    location.href = authMode.includes("Cloudflare Access") ? "/cdn-cgi/access/logout" : "/login";
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
      <section className="admin-panel"><div className="panel-title"><div><h2>Entreprises enregistrées</h2><p>Liste backend — lecture seule, sans données inventées.</p></div><span className="panel-icon">▦</span></div>
        {businesses.length === 0 ? <p className="empty-state">{loading ? "Chargement…" : "Aucune entreprise enregistrée dans D1."}</p> : <div className="table-scroll"><table className="business-table"><thead><tr><th>Entreprise</th><th>Type / pays</th><th>Membres</th><th>Produits</th><th>Ventes</th><th>Revenu</th><th>Statut</th></tr></thead><tbody>{businesses.map((business) => <tr key={business.id}><td><b>{business.name}</b><small>{business.id.slice(0, 8)}</small></td><td>{business.business_type}<small>{business.country_code} · {business.currency_code}</small></td><td>{number(business.members)}</td><td>{number(business.products)}</td><td>{number(business.sales)}</td><td>{money(business.revenue, business.currency_code)}</td><td><span className={"business-status " + (business.status === "active" ? "active" : "inactive")}>{business.status}</span></td></tr>)}</tbody></table></div>}
      </section>
      <section className="admin-panel"><div className="panel-title"><div><h2>Ventes récentes</h2><p>50 dernières transactions réelles, sans action de modification.</p></div><span className="panel-icon">€</span></div>
        {sales.length === 0 ? <p className="empty-state">{loading ? "Chargement…" : "Aucune vente dans D1."}</p> : <div className="table-scroll"><table className="business-table"><thead><tr><th>Date</th><th>Entreprise</th><th>Référence</th><th>Paiement</th><th>Montant</th><th>État</th></tr></thead><tbody>{sales.map((sale) => <tr key={sale.id}><td>{date(sale.sold_at)}</td><td>{sale.business_name || sale.business_id.slice(0,8)}</td><td>{sale.sale_number}</td><td>{sale.payment_method || "—"}<small>{statusLabel(sale.payment_status)}</small></td><td>{money(sale.total, sale.currency_code)}</td><td><span className={"business-status " + (sale.status === "completed" ? "active" : "inactive")}>{statusLabel(sale.status)}</span></td></tr>)}</tbody></table></div>}
      </section>
      <section className="admin-panel"><div className="panel-title"><div><h2>Stocks sous seuil</h2><p>Inventaire du dépôt principal — quantités comparées au seuil produit.</p></div><span className="panel-icon">▤</span></div>
        {!inventory?.data?.length ? <p className="empty-state">{loading ? "Chargement…" : "Aucun produit sous son seuil de stock."}</p> : <div className="table-scroll"><table className="business-table"><thead><tr><th>Entreprise</th><th>Produit</th><th>Référence</th><th>Stock</th><th>Seuil</th><th>Prix</th></tr></thead><tbody>{inventory.data.map((item, i) => <tr key={item.product_name + "-" + i}><td>{item.business_name || "—"}</td><td><b>{item.product_name}</b><small>{item.warehouse_name || "Dépôt non défini"}</small></td><td>{item.sku || "—"}</td><td><span className="stock-warning">{number(item.quantity)}</span></td><td>{number(item.min_quantity)}</td><td>{money(item.sale_price, item.currency_code)}</td></tr>)}</tbody></table></div>}
        {inventory?.capped && <p className="table-note">Affichage limité à 100 produits; total calculé: {number(inventory.count)}.</p>}
      </section>
      <section className="admin-panel"><div className="panel-title"><div><h2>Synchronisation mobile</h2><p>État des opérations côté serveur et derniers appareils observés.</p></div><span className="panel-icon">↻</span></div>
        <div className="sync-summary">{["queued","applied","conflict","rejected","failed","processing"].map((key) => <div className="sync-count" key={key}><small>{statusLabel(key)}</small><b>{number(syncData?.summary?.[key])}</b></div>)}</div>
        {!syncData?.operations?.length ? <p className="empty-state">{loading ? "Chargement…" : "Aucune opération de synchronisation enregistrée."}</p> : <div className="table-scroll"><table className="business-table"><thead><tr><th>Reçue</th><th>Entreprise</th><th>Type</th><th>Opération</th><th>Appareil</th><th>Utilisateur</th><th>État</th></tr></thead><tbody>{syncData.operations.map((op) => <tr key={op.id}><td>{date(op.created_at)}</td><td>{op.business_name || "—"}</td><td>{op.entity_type}</td><td>{op.operation_type}<small>{op.entity_id?.slice(0,8) || "—"}</small></td><td>{op.platform || "—"}</td><td>{op.actor_email || "—"}</td><td><span className={"business-status " + (op.status === "applied" ? "active" : "inactive")}>{statusLabel(op.status)}</span></td></tr>)}</tbody></table></div>}
      </section>
      <section className="admin-panel"><div className="panel-title"><div><h2>État des services</h2><p>Health checks réellement exécutés.</p></div><span className="panel-icon">⌁</span></div>
        {serviceRow("↗", "API GeStock", "Health check", status?.api?.ok)}
        {serviceRow("▦", "Cloudflare D1", "Base et schéma", status?.d1?.ok)}
        {serviceRow("♙", "Cloudflare Access", "Protection edge (activation manuelle requise)", authMode.includes("Cloudflare Access"))}
      </section>
      <section className="admin-panel"><div className="panel-title"><div><h2>Fonctionnalités</h2><p>État du backend : connectées ou non implémentées.</p></div></div><div className="capability-list">{capabilities.map((item) => <article className="capability" key={item.name}><div><b>{item.name}</b><small>{item.detail}</small></div><span className={item.state === "Connecté" ? "cap-ready" : "cap-missing"}>{item.state}</span></article>)}</div></section>
      <footer>GeStock Admin · {status?.checkedAt ? new Date(status.checkedAt).toLocaleString("fr-FR") : "diagnostic en attente"}</footer>
    </main>
  </div>;
}
