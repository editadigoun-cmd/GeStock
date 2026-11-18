// Cloudflare Worker: GeStock Neon Auth proxy.
// Public entry point: https://gestock-auth-proxy.ccds22431.workers.dev/auth
// Mobile clients do not send a browser Origin header. Supply the same trusted
// application origin used by the admin web app so Better Auth's origin checks
// accept requests forwarded by this server-side proxy.
const UPSTREAM = "https://ep-holy-boat-banyu93m.neonauth.c-8.eu-central-1.aws.neon.tech/gestock/auth";
const TRUSTED_APP_ORIGIN = "https://gestock-admin.ccds22431.workers.dev";

async function handle(request) {
  const incoming = new URL(request.url);

  if (incoming.pathname === "/health") {
    return Response.json({ service: "gestock-auth-proxy", status: "ok" }, {
      headers: { "Cache-Control": "no-store" }
    });
  }

  if (incoming.pathname === "/health/upstream") {
    try {
      const response = await fetch(UPSTREAM + "/get-session", {
        headers: { "Accept": "application/json", "Origin": TRUSTED_APP_ORIGIN }
      });
      return Response.json({
        service: "gestock-auth-proxy",
        proxy: "ok",
        neonAuthReachable: response.status < 500,
        neonAuthStatus: response.status
      }, { headers: { "Cache-Control": "no-store" } });
    } catch (error) {
      return Response.json({
        service: "gestock-auth-proxy",
        proxy: "ok",
        neonAuthReachable: false,
        error: String(error)
      }, { status: 502, headers: { "Cache-Control": "no-store" } });
    }
  }

  if (incoming.pathname !== "/auth" && !incoming.pathname.startsWith("/auth/")) {
    return Response.json({ error: "Not found" }, { status: 404 });
  }

  const suffix = incoming.pathname.slice(5);
  const target = new URL(UPSTREAM + suffix + incoming.search);
  const headers = new Headers(request.headers);
  headers.delete("host");
  headers.delete("content-length");
  headers.delete("cf-connecting-ip");
  headers.delete("accept-encoding");

  // Preserve a real browser origin when present; for native mobile requests,
  // provide the already-authorized GeStock admin origin.
  if (!headers.has("origin")) headers.set("Origin", TRUSTED_APP_ORIGIN);
  if (!headers.has("accept")) headers.set("Accept", "application/json");

  const init = { method: request.method, headers, redirect: "manual" };
  if (request.method !== "GET" && request.method !== "HEAD") init.body = request.body;

  try {
    const response = await fetch(new Request(target, init));
    const outHeaders = new Headers(response.headers);
    outHeaders.set("Cache-Control", "no-store");
    outHeaders.set("X-GeStock-Auth-Proxy", "cloudflare");
    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers: outHeaders
    });
  } catch (error) {
    return Response.json({ error: "Auth upstream unavailable", detail: String(error) }, {
      status: 502,
      headers: { "Cache-Control": "no-store" }
    });
  }
}

addEventListener("fetch", event => event.respondWith(handle(event.request)));
