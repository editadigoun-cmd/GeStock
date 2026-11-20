# Configurer les invitations par e-mail GeStock

Les invitations de membres utilisent Resend depuis le Cloudflare Worker. Aucun mot de passe ni jeton n'est stocké dans le code.

## 1. Configurer l'expéditeur

1. Créer un compte Resend.
2. Ajouter et vérifier un domaine d'envoi (DNS SPF/DKIM selon les instructions Resend).
3. Choisir une adresse expéditrice sur ce domaine, par exemple `GeStock <invitations@votredomaine.com>`.

## 2. Définir les secrets Cloudflare

Dans le dossier `backend`, avec Wrangler connecté au bon compte :

```bash
npx wrangler secret put RESEND_API_KEY
npx wrangler secret put EMAIL_FROM
```

- `RESEND_API_KEY`: clé API Resend avec permission d'envoi.
- `EMAIL_FROM`: adresse expéditrice vérifiée, par exemple `GeStock <invitations@votredomaine.com>`.

## 3. URL publique

Le Worker utilise `API_BASE_URL` pour construire le lien d'acceptation. Le défaut est l'URL du Worker GeStock. Si l'URL change, définir la variable dans `backend/wrangler.jsonc` ou dans les variables Worker Cloudflare.

## 4. Parcours

- Le propriétaire/gestionnaire saisit l'e-mail et le rôle dans **Employés → Inviter**.
- Le serveur crée un jeton aléatoire dont seul le hash est stocké en D1.
- L'invitation expire après 7 jours. Une nouvelle invitation au même e-mail révoque les anciennes invitations en attente.
- Le lien ouvre une page web. La personne peut se connecter à un compte existant ou créer un compte.
- Le compte connecté doit correspondre à l'adresse invitée; l'acceptation crée/réactive le membership dans l'entreprise.
- Les invitations en attente apparaissent dans l'écran Employés.

## 5. Sécurité

- Le jeton d'invitation est à usage unique, expire et est stocké sous forme de hash.
- L'acceptation vérifie que l'adresse du compte correspond à l'adresse invitée.
- Seuls propriétaires et gestionnaires actifs peuvent inviter.
- Les invitations sont envoyées via HTTPS (Resend).
