import { NextRequest, NextResponse } from "next/server";

// Stable Cloudflare-to-Cloudflare route; Neon origin stays inside the auth proxy.
const AUTH_PROXY_BASE = "https://gestock-auth-proxy.ccds22431.workers.dev/auth";

async function proxy(req: NextRequest, context: { params: Promise<{path:string[]}> }) {
 const {path}=await context.params;
 const suffix=path.map(part=>encodeURIComponent(part)).join("/");
 const url=new URL(suffix,AUTH_PROXY_BASE+"/");
 url.search=req.nextUrl.search;
 const headers=new Headers(req.headers);
 headers.delete("host");
 headers.delete("content-length");
 headers.delete("cf-connecting-ip");
 try {
  const upstream=await fetch(url,{method:req.method,headers,body:["GET","HEAD"].includes(req.method)?undefined:await req.arrayBuffer(),redirect:"manual",cache:"no-store"});
  const responseHeaders=new Headers(upstream.headers);
  responseHeaders.delete("content-encoding");
  responseHeaders.delete("content-length");
  responseHeaders.set("Cache-Control","no-store");
  return new NextResponse(upstream.body,{status:upstream.status,headers:responseHeaders});
 } catch (error) {
  return NextResponse.json({error:"AUTH_PROXY_UNAVAILABLE",detail:String(error)},{status:502});
 }
}
export const GET=proxy;
export const POST=proxy;
export const PUT=proxy;
export const PATCH=proxy;
export const DELETE=proxy;
export const OPTIONS=proxy;
