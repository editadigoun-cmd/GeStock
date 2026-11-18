import { NextRequest, NextResponse } from "next/server";

const AUTH_PROXY_BASE = "https://gestock-auth-proxy.ccds22431.workers.dev/auth";

async function proxy(req: NextRequest, context: { params: Promise<{path:string[]}> }) {
 const {path}=await context.params;
 const suffix=path.map(part=>encodeURIComponent(part)).join("/");
 const target=`${AUTH_PROXY_BASE}/${suffix}${req.nextUrl.search}`;
 const headers=new Headers(req.headers);
 headers.delete("host");
 headers.delete("content-length");
 headers.delete("cf-connecting-ip");
 try {
  const upstream=await fetch(target,{method:req.method,headers,body:["GET","HEAD"].includes(req.method)?undefined:await req.arrayBuffer(),redirect:"manual",cache:"no-store"});
  const responseHeaders=new Headers(upstream.headers);
  responseHeaders.delete("content-encoding");
  responseHeaders.delete("content-length");
  responseHeaders.set("Cache-Control","no-store");
  const contentType=responseHeaders.get("content-type")||"";
  if(upstream.status===404 && (contentType.includes("text/html")||contentType.includes("text/plain"))){
   const body=await upstream.text();
   return NextResponse.json({
    error:"AUTH_ROUTE_404_HTML",
    requestedPath:req.nextUrl.pathname,
    forwardedUrl:target,
    upstreamStatus:upstream.status,
    upstreamContentType:contentType,
    upstreamServer:responseHeaders.get("server"),
    upstreamCfRay:responseHeaders.get("cf-ray"),
    upstreamBodyStart:body.slice(0,900)
   },{status:502,headers:{"Cache-Control":"no-store"}});
  }
  responseHeaders.set("X-GeStock-Admin-Auth-Path",req.nextUrl.pathname);
  responseHeaders.set("X-GeStock-Admin-Forwarded-To",target);
  return new NextResponse(upstream.body,{status:upstream.status,headers:responseHeaders});
 } catch(error) {
  return NextResponse.json({error:"AUTH_PROXY_UNAVAILABLE",detail:String(error),requestedPath:req.nextUrl.pathname,forwardedUrl:target},{status:502});
 }
}
export const GET=proxy;
export const POST=proxy;
export const PUT=proxy;
export const PATCH=proxy;
export const DELETE=proxy;
export const OPTIONS=proxy;
