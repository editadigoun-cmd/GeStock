import {NextResponse} from "next/server";
import {headers} from "next/headers";
// Trusted only after Cloudflare Access is enabled for the entire admin Worker.
export async function GET(){const h=await headers();return NextResponse.json({email:(h.get("cf-access-authenticated-user-email")||"").toLowerCase()},{headers:{"Cache-Control":"no-store"}});}
