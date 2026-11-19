const ITERATIONS=310000;const enc=new TextEncoder();
function b64(v:Uint8Array){let s='';for(const n of v)s+=String.fromCharCode(n);return btoa(s).replace(/=/g,'');}
function unb64(v:string){const s=v.replace(/-/g,'+').replace(/_/g,'/');return Uint8Array.from(atob(s+'='.repeat((4-s.length%4)%4)),c=>c.charCodeAt(0));}
async function derive(p:string,s:Uint8Array,n:number){const k=await crypto.subtle.importKey('raw',enc.encode(p),'PBKDF2',false,['deriveBits']);const safeSalt=new Uint8Array(s).buffer;return new Uint8Array(await crypto.subtle.deriveBits({name:'PBKDF2',hash:'SHA-256',salt:safeSalt,iterations:n},k,256));}
export async function hashPassword(p:string){const s=crypto.getRandomValues(new Uint8Array(16));return 'pbkdf2-sha256$'+ITERATIONS+'$'+b64(s)+'$'+b64(await derive(p,s,ITERATIONS));}
export async function verifyPassword(p:string,h:string){const a=h.split('$');if(a.length!==4||a[0]!=='pbkdf2-sha256')return false;const n=Number(a[1]);if(!Number.isInteger(n)||n<100000||n>1000000)return false;try{const x=await derive(p,unb64(a[2]),n),y=unb64(a[3]);if(x.length!==y.length)return false;let d=0;for(let i=0;i<x.length;i++)d|=x[i]^y[i];return d===0;}catch{return false;}}
export function createSessionToken(){return b64(crypto.getRandomValues(new Uint8Array(32))).replace(/\+/g,'-').replace(/\//g,'_');}
export async function hashSessionToken(t:string){return b64(new Uint8Array(await crypto.subtle.digest('SHA-256',enc.encode(t))));}
