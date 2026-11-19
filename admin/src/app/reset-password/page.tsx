"use client";

import { useState } from "react";
import type { FormEvent } from "react";

export default function ResetPassword() {
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    const token = new URLSearchParams(window.location.search).get("token");
    if (!token) {
      setError("Lien invalide ou expiré. Recommence depuis « Mot de passe oublié ».");
      return;
    }
    if (password.length < 8) {
      setError("Le mot de passe doit contenir au moins 8 caractères.");
      return;
    }
    if (password !== confirm) {
      setError("Les deux mots de passe ne correspondent pas.");
      return;
    }

    setBusy(true);
    try {
      const response = await fetch("/api/auth/reset-password", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        credentials: "include",
        body: JSON.stringify({ token, newPassword: password }),
      });
      const raw = await response.text();
      let data: { message?: string; error?: string } = {};
      try {
        data = raw ? JSON.parse(raw) : {};
      } catch {
        // Keep the raw response for a useful error if it is not JSON.
      }
      if (!response.ok) {
        throw new Error(data.message || data.error || raw || `Erreur HTTP ${response.status}`);
      }
      setDone(true);
      window.history.replaceState({}, document.title, window.location.pathname);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Réinitialisation impossible.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="login">
      <form onSubmit={submit}>
        <div className="logo">G</div>
        <small>RÉCUPÉRATION DU COMPTE</small>
        <h1>GeStock <i>Admin</i></h1>
        {done ? (
          <>
            <p>Mot de passe réinitialisé avec succès.</p>
            <a href="/login">Retour à la connexion</a>
          </>
        ) : (
          <>
            <p>Définis ton nouveau mot de passe administrateur.</p>
            <label htmlFor="new-password">Nouveau mot de passe</label>
            <input
              id="new-password"
              type="password"
              required
              minLength={8}
              autoComplete="new-password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
            />
            <label htmlFor="confirm-password">Confirmer le mot de passe</label>
            <input
              id="confirm-password"
              type="password"
              required
              minLength={8}
              autoComplete="new-password"
              value={confirm}
              onChange={(event) => setConfirm(event.target.value)}
            />
            {error && <div className="error">{error}</div>}
            <button type="submit" disabled={busy}>
              {busy ? "Enregistrement…" : "Réinitialiser le mot de passe"}
            </button>
          </>
        )}
      </form>
    </main>
  );
}
