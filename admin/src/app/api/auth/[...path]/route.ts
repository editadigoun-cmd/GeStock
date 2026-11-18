import { NextRequest, NextResponse } from "next/server";

const AUTH_PROXY_BASE = "https://gestock-auth-proxy.ccds22431.workers.dev/auth";
const APP_ORIGIN = "https://gestock-admin.ccds22431.workers.dev";

async function proxy(req: NextRequest, context: { params: Promise<{ path: string[] }> }) {
  const { path } = await context.params;
  const suffix = path.map((part) => encodeURIComponent(part)).join("/");
  const target = `${AUTH_PROXY_BASE}/${suffix}${req.nextUrl.search}`;

  // Forward only headers needed by Better Auth. In particular, do not forward
  // Cloudflare/Next internal headers or the incoming compression negotiation.
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
      if (value) responseHeaders.set(name, value);
    }
    responseHeaders.set("Cache-Control", "no-store");
    responseHeaders.set("X-GeStock-Auth-Route", "admin-to-cloudflare-proxy");

    const contentType = upstream.headers.get("content-type") || "";
    if (upstream.status === 404 && contentType.includes("text/html")) {
      const body = await upstream.text();
      return NextResponse.json({
        error: "AUTH_UPSTREAM_ROUTE_NOT_FOUND",
        requestedPath: req.nextUrl.pathname,
        forwardedUrl: target,
        upstreamStatus: upstream.status,
        upstreamContentType: contentType,
        upstreamServer: upstream.headers.get("server"),
        upstreamCfRay: upstream.headers.get("cf-ray"),
        upstreamBodyStart: body.slice(0, 500),
      }, { status: 502, headers: { "Cache-Control": "no-store" } });
    }

    return new NextResponse(upstream.body, {
      status: upstream.status,
      headers: responseHeaders,
    });
  } catch (error) {
    return NextResponse.json({
      error: "AUTH_PROXY_UNAVAILABLE",
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
