# GeStock — Audit fonctionnel initial

Audit effectué sur `main` le 20 novembre 2026 à partir de README, docs/IMPLEMENTATION_STATUS.md, docs/ARCHITECTURE.md, backend/src/schema.ts et mobile/lib/data/services/sync_service.dart.

> Cet inventaire est un état initial. « Présent en base/backend » ne signifie pas que l'écran mobile existe ni que le parcours est fonctionnel. Les tests sur appareil restent nécessaires.

## Statuts

- **Présent / testé** : attesté par les documents et/ou tests du dépôt.
- **Partiel / à vérifier** : structure ou code existant, interface/parcours non confirmés.
- **Manquant / incomplet** : explicitement identifié comme non livré ou absent.

## Inventaire

| Fonctionnalité | État initial | Vérification / travail restant |
|---|---|---|
| Inscription / connexion | Présent, API testée | Test physique sur appareil |
| Session, déconnexion, changement de mot de passe | API testée | UX mobile et tests appareil |
| Multi-entreprises / membres | Structure backend | Parcours mobile, permissions |
| Création entreprise | Présent | Test réel |
| Catalogue produits | Partiel | Vérifier CRUD mobile et synchronisation |
| Catégories | Structure prévue | Vérifier écran et CRUD |
| Codes-barres / SKU | Champs disponibles | Vérifier scan et recherche |
| Stock / mouvements | Partiel | Vérifier entrées, sorties, ajustements |
| Inventaire | À vérifier / incomplet | Comptage, écarts, validation |
| Entrepôts / magasins | Structure backend | Écrans et workflow |
| Transferts entre magasins | Incomplet | Implémenter |
| Clients | Backend/schema existe; UI mobile absente | CRUD local/cloud, association facultative à une vente |
| Fournisseurs | Backend/schema existe | UI et parcours à vérifier |
| Achats | Incomplet | Commande, réception, mise à jour du stock |
| Ventes / POS | Présent, workflow incomplet | Parcours complet, panier, paiement, validation |
| Paiements multiples | Schema ventes/paiements | UI et tests à vérifier |
| Retours / remboursements | Manquant | Implémenter |
| Crédit / dette client | Manquant | Implémenter |
| Sessions de caisse | Incomplet | Ouverture, clôture, rapprochement |
| Dépenses | Schema backend existe | UI, catégories et reporting |
| Reçus / impression | Manquant | Implémenter |
| Tableau de bord / statistiques | Limité | KPI, filtres et périodes |
| Synchronisation hors ligne | Code/outbox présent | Test appareil; sync cloud et conflits |
| Résolution conflits sync | Incomplète | UI et stratégies |
| Multi-appareils | Prévu | Tester données partagées |
| Gestion utilisateurs / rôles | Admin CRUD incomplet | Implémenter |
| Invitations | Manquant | Implémenter |
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
