import {NextResponse} from "next/server";
import {headers} from "next/headers";
// Do not trust Access identity headers until the Worker is actually protected at the Cloudflare edge.
export async function GET(){
  if(process.env.CLOUDFLARE_ACCESS_ENABLED!=="true")return NextResponse.json({email:""},{headers:{"Cache-Control":"no-store"}});
  const h=await headers();
  return NextResponse.json({email:(h.get("cf-access-authenticated-user-email")||"").toLowerCase()},{headers:{"Cache-Control":"no-store"}});
}
