import {NextResponse} from "next/server";
const API=process.env.GESTOCK_API_URL||"https://gestock-api.ccds22431.workers.dev";
async function check(path:string){try{const r=await fetch(API+path,{cache:"no-store",signal:AbortSignal.timeout(7000)});const d=await r.json();return {...d,ok:r.ok&&d?.ok===true};}catch(e){return {ok:false,error:e instanceof Error?e.message:"Request failed"};}}
export async function GET(){const[api,d1]=await Promise.all([check("/health"),check("/health/d1")]);return NextResponse.json({api,d1,checkedAt:new Date().toISOString(),errors:[api,d1].filter(x=>!x.ok).map(x=>x.error||"Service indisponible")},{headers:{"Cache-Control":"no-store"}});}
