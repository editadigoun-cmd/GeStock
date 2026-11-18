// Cloudflare Worker: GeStock Neon Auth DNS proxy.
// Public entry point: https://gestock-auth-proxy.ccds22431.workers.dev/auth
// Keeps the Neon Auth origin server-side so Android clients only resolve workers.dev.
const UPSTREAM = "https://ep-holy-boat-banyu93m.neonauth.c-8.eu-central-1.aws.neon.tech/gestock/auth";

async function handle(request) {
  const incoming = new URL(request.url);

  if (incoming.pathname === "/health") {
    return new Response(JSON.stringify({ service: "gestock-auth-proxy", status: "ok" }), {
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store" }
    });
  }

  if (incoming.pathname !== "/auth" && !incoming.pathname.startsWith("/auth/")) {
    return new Response(JSON.stringify({ error: "Not found" }), {
      status: 404,
      headers: { "Content-Type": "application/json" }
    });
  }

  const suffix = incoming.pathname.slice(5);
  const target = new URL(UPSTREAM + suffix + incoming.search);
  const headers = new Headers(request.headers);
  headers.delete("host");
  headers.delete("content-length");
  headers.delete("cf-connecting-ip");

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
    return new Response(JSON.stringify({ error: "Auth upstream unavailable", detail: String(error) }), {
      status: 502,
      headers: { "Content-Type": "application/json" }
    });
  }
}

addEventListener("fetch", event => event.respondWith(handle(event.request)));
