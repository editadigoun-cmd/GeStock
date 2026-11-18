import { NextRequest, NextResponse } from "next/server";
const base = process.env.NEON_AUTH_BASE_URL;
async function proxy(req: NextRequest, context: { params: Promise<{path:string[]}> }) {
 if (!base) return NextResponse.json({error:"AUTH_NOT_CONFIGURED"},{status:503});
 const {path}=await context.params; const url=new URL(path.join("/"),base.endsWith("/")?base:base+"/"); url.search=req.nextUrl.search;
 const headers=new Headers(req.headers); headers.delete("host"); headers.delete("content-length");
 try { const upstream=await fetch(url,{method:req.method,headers,body:["GET","HEAD"].includes(req.method)?undefined:await req.arrayBuffer(),redirect:"manual",cache:"no-store"}); const response=new NextResponse(upstream.body,{status:upstream.status,headers:upstream.headers}); response.headers.delete("content-encoding"); response.headers.delete("content-length"); return response; }
 catch { return NextResponse.json({error:"AUTH_UNAVAILABLE"},{status:502}); }
}
export const GET=proxy; export const POST=proxy; export const PUT=proxy; export const PATCH=proxy; export const DELETE=proxy; export const OPTIONS=proxy;