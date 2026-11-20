# GeStock — Audit fonctionnel initial

Audit effectué sur `main` le 20 novembre 2026 à partir de README, docs/IMPLEMENTATION_STATUS.md, docs/ARCHITECTURE.md, backend/src/schema.ts et mobile/lib/data/services/sync_service.dart.

> Cet inventaire est évolutif. « Présent en base/backend » ne signifie pas que l'écran mobile existe ni que le parcours est fonctionnel. Les tests sur appareil restent nécessaires. Progression du 20 novembre 2026 : Clients, Fournisseurs, Achats/Réceptions, Retours, Crédit, Caisse, Dépenses, Rapports, Support, Inventaire physique et reçus PDF sont développés. La génération du reçu 80 mm et l'impression/partage natifs sont ajoutés à l'historique des ventes. CI Flutter/backend réussie; déploiement Cloudflare et build APK validés. Les tests physiques restent requis.

Progression 20 novembre 2026 : module Employés et invitations par e-mail ajoutés (lien sécurisé, expiration 7 jours, inscription ou connexion puis acceptation). Config Resend à compléter avant envoi réel : RESEND_API_KEY et EMAIL_FROM comme secrets Cloudflare. Rapports & Statistiques ajoutés. Permissions métier vérifiées côté API pour les principaux flux et synchronisation

## Statuts

- **Présent / testé** : attesté par les documents et/ou tests du dépôt.
- **Partiel / à vérifier** : structure ou code existant, interface/parcours non confirmés.
- **Manquant / incomplet** : explicitement identifié comme non livré ou absent.

## Inventaire

| Fonctionnalité | État initial | Vérification / travail restant |
|---|---|---|
| Inscription / connexion | Présent, API testée | Test physique sur appareil |
| Session, déconnexion, changement de mot de passe | API testée | UX mobile et tests appareil |
| Multi-entreprises / membres | Développé (employés) | Liste, invitations par e-mail, rôles gestionnaire/caissier/employé, activation/désactivation; permissions détaillées à compléter |
| Création entreprise | Présent | Test réel |
| Catalogue produits | Partiel | Vérifier CRUD mobile et synchronisation |
| Catégories | Structure prévue | Vérifier écran et CRUD |
| Codes-barres / SKU | Champs disponibles | Vérifier scan et recherche |
| Stock / mouvements | Partiel | Vérifier entrées, sorties, ajustements |
| Inventaire | À vérifier / incomplet | Comptage, écarts, validation |
| Entrepôts / magasins | Structure backend | Écrans et workflow |
| Transferts entre magasins | Incomplet | Implémenter |
| Clients | Développé, CI passée, API déployée | CRUD mobile hors ligne, API cloud et sync push, sélection facultative en POS; tests appareil à confirmer |
| Fournisseurs | Développé, CI passée, API déployée | CRUD mobile hors ligne, API cloud et sync push; tests appareil à confirmer |
| Achats | Développé, CI passée | Réception multi-produits hors ligne, mise à jour locale du stock, API cloud et sync transactionnelle; tests appareil à confirmer |
| Ventes / POS | Présent, workflow incomplet | Parcours complet, panier, paiement, validation |
| Paiements multiples | Schema ventes/paiements | UI et tests à vérifier |
| Retours / remboursements | Développé, CI réussie | Retour partiel/total par vente, validation quantités, motif, méthode de remboursement, réintégration stock, ajustement dette client et sync offline; tests appareil à confirmer |
| Crédit / dette client | Développé, CI passée, migration/API déployées | Vente à crédit avec acompte ou paiement différé, client obligatoire, solde dû local/cloud, encaissements ultérieurs hors ligne et historique API; tests appareil et parcours métier à confirmer |
| Rapports & statistiques | Développé, CI à confirmer | Chiffre d’affaires, encaissements, dépenses, marge brute estimée, résultat estimé, stock, stock bas et top produits sur périodes aujourd’hui/7/30 jours (données locales); tests appareil à confirmer |
| Sessions de caisse | Développé, CI réussie | Ouverture fond initial, calcul espèces (ventes, recouvrements, dépenses, remboursements), montant théorique, clôture, montant réel, écart, historique local/cloud et sync hors ligne; tests appareil à confirmer |
| Dépenses | Développé, CI passée, API déployée | Enregistrement hors ligne, catégories et synchronisation; tests appareil à confirmer |
| Reçus / impression | Développé | Reçu PDF 80 mm depuis l’historique de vente, impression/partage natifs; test imprimante physique à faire |
| Tableau de bord / statistiques | Limité | KPI, filtres et périodes |
| Synchronisation hors ligne | CI passée; pull cloud des niveaux de stock | Test appareil; sync cloud et conflits |
| Résolution conflits sync | Incomplète | UI et stratégies |
| Multi-appareils | Prévu | Tester données partagées |
| Gestion utilisateurs / rôles | Partiel | API applique les permissions par rôle sur les principaux flux; audit exhaustif et restrictions UI restantes |
| Invitations employés | Développé, CI à confirmer | E-mail Resend, lien sécurisé expirant après 7 jours, inscription ou connexion sur page web, acceptation et rattachement au business; secrets e-mail à configurer |
| Email verification | Manquant | Implémenter |
| Récupération mot de passe par email | Manquant | Implémenter |
| Journal/audit | Tables prévues | Interface et événements |
| Support / assistance | Incomplet | Outils admin |
| Abonnements | Non finalisés | Plans, droits, limites, billing |
| Publicité / monétisation | Non intégrée | Consentement, placements et configuration |
| Paramètres complets | Incomplets | Entreprise, devise, taxes, unités, préférences |
| Admin console | Read-only | CRUD, audit, support, settings |
| Android release | APK build vérifié selon docs | Réinstaller la dernière build et test physique |
| iOS / stores | Non livré | Build, signatures et publication |

## Tables backend repérées

Le schema contient notamment: users, organizations, organization_memberships, businesses, business_memberships, business_locations, sync_devices, product_categories, products, warehouses, stock_levels, stock_movements, customers, suppliers, purchases, purchase_items, sales, sale_items, sale_payments, cash_registers, cash_sessions, expenses, audit_logs, sync_operations.

## Priorité proposée

1. **P0 — Fiabilité** : synchronisation cloud physique, état sync visible, sauvegarde et conflits.
2. **P1 — Gestion de base** : clients, fournisseurs, catégories, produits, stock et inventaire.
3. **P2 — Commerce** : POS, paiements, crédit client, retours, remboursements, caisse, reçus.
4. **P3 — Logistique** : achats, réception, fournisseurs, entrepôts et transferts.
5. **P4 — Pilotage** : statistiques, dépenses, audit et rapports.
6. **P5 — Administration & business** : rôles, invitations, récupération de compte, settings, abonnements et publicité.
7. **P6 — Publication** : tests appareils, sécurité, AAB/Play Store et iOS.

## Règle de suivi

Chaque fonctionnalité doit être marquée : **Prévue → Développée → Visible → Testée → Validée**. Une fonctionnalité ne sera pas déclarée terminée sur la seule base de la présence d'une table ou d'un endpoint.
