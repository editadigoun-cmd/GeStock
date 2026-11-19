import { NextRequest, NextResponse } from "next/server";

const ADMIN_EMAIL = "editadigoun@gmail.com";
const AUTH_BASE = process.env.NEON_AUTH_BASE_URL || "https://gestock-auth-proxy.ccds22431.workers.dev/auth";
const API_BASE = process.env.GESTOCK_API_URL || "https://gestock-api.ccds22431.workers.dev";
const APP_ORIGIN = "https://gestock-admin.ccds22431.workers.dev";

export async function proxyAdminApi(request: NextRequest, endpoint: string) {
  if (process.env.CLOUDFLARE_ACCESS_ENABLED === "true") {
    const accessEmail = (request.headers.get("cf-access-authenticated-user-email") || "").toLowerCase();
    if (accessEmail !== ADMIN_EMAIL) return NextResponse.json({ error: "ACCESS_ADMIN_REQUIRED" }, { status: 403, headers: { "Cache-Control": "no-store" } });
  }
  const cookie = request.headers.get("cookie") || "";
  if (!cookie) return NextResponse.json({ error: "SESSION_REQUIRED" }, { status: 401, headers: { "Cache-Control": "no-store" } });
  try {
    const sessionResponse = await fetch(AUTH_BASE + "/get-session", {
      headers: { cookie, origin: APP_ORIGIN, accept: "application/json" }, cache: "no-store",
    });
    if (!sessionResponse.ok) return NextResponse.json({ error: "SESSION_REQUIRED" }, { status: 401, headers: { "Cache-Control": "no-store" } });
    const session = await sessionResponse.json() as any;
    const user = session?.user || session?.data?.user;
    if (String(user?.email || "").toLowerCase() !== ADMIN_EMAIL) {
      return NextResponse.json({ error: "ADMIN_REQUIRED" }, { status: 403, headers: { "Cache-Control": "no-store" } });
    }
    const tokenResponse = await fetch(AUTH_BASE + "/token", {
      headers: { cookie, origin: APP_ORIGIN, accept: "application/json" }, cache: "no-store",
    });
    if (!tokenResponse.ok) return NextResponse.json({ error: "TOKEN_REQUIRED" }, { status: 401, headers: { "Cache-Control": "no-store" } });
    const tokenData = await tokenResponse.json() as any;
    const token = tokenData?.token || tokenData?.accessToken || tokenData?.data?.token;
    if (typeof token !== "string" || !token) return NextResponse.json({ error: "TOKEN_REQUIRED" }, { status: 401, headers: { "Cache-Control": "no-store" } });
    const upstream = await fetch(API_BASE + endpoint, {
      headers: { Authorization: "Bearer " + token, accept: "application/json" }, cache: "no-store",
    });
    const body = await upstream.text();
    let parsed: unknown;
    try { parsed = body ? JSON.parse(body) : {}; } catch { parsed = { error: "INVALID_API_RESPONSE" }; }
    return NextResponse.json(parsed, { status: upstream.status, headers: { "Cache-Control": "no-store" } });
  } catch {
    return NextResponse.json({ error: "ADMIN_API_UNAVAILABLE" }, { status: 502, headers: { "Cache-Control": "no-store" } });
  }
}
