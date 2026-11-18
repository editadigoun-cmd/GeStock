import { NextRequest, NextResponse } from "next/server";

// The admin Worker must call Neon Auth directly. Calling the separate
// gestock-auth-proxy Worker from another Worker in the same Cloudflare account
// triggers Cloudflare error 1042 (Worker-to-Worker fetch restriction).
const AUTH_UPSTREAM_BASE = "https://ep-holy-boat-banyu93m.neonauth.c-8.eu-central-1.aws.neon.tech/gestock/auth";
const APP_ORIGIN = "https://gestock-admin.ccds22431.workers.dev";

async function proxy(req: NextRequest, context: { params: Promise<{ path: string[] }> }) {
  const { path } = await context.params;
  const suffix = path.map((part) => encodeURIComponent(part)).join("/");
  const target = `${AUTH_UPSTREAM_BASE}/${suffix}${req.nextUrl.search}`;

  const headers = new Headers();
  for (const name of ["accept", "content-type", "cookie", "authorization", "user-agent", "x-requested-with"]) {
    const value = req.headers.get(name);
    if (value) headers.set(name, value);
  }
  headers.set("origin", req.headers.get("origin") || APP_ORIGIN);
  headers.set("accept", "application/json");

  try {
    const upstream = await fetch(target, {
      method: req.method,
      headers,
      body: ["GET", "HEAD"].includes(req.method) ? undefined : await req.arrayBuffer(),
      redirect: "manual",
      cache: "no-store",
    });

    const responseHeaders = new Headers();
    for (const name of ["content-type", "set-cookie", "location", "www-authenticate"]) {
      const value = upstream.headers.get(name);
      if (value) responseHeaders.append(name, value);
    }
    responseHeaders.set("Cache-Control", "no-store");

    return new NextResponse(upstream.body, {
      status: upstream.status,
      headers: responseHeaders,
    });
  } catch (error) {
    return NextResponse.json({
      error: "AUTH_UPSTREAM_UNAVAILABLE",
      detail: String(error),
      requestedPath: req.nextUrl.pathname,
      forwardedUrl: target,
    }, { status: 502, headers: { "Cache-Control": "no-store" } });
  }
}

export const GET = proxy;
export const POST = proxy;
export const PUT = proxy;
export const PATCH = proxy;
export const DELETE = proxy;
export const OPTIONS = proxy;
