export async function sendTransactionalEmail(env:{RESEND_API_KEY?:string;EMAIL_FROM?:string},to:string,subject:string,html:string){
 if(!env.RESEND_API_KEY||!env.EMAIL_FROM)return {configured:false,ok:false};
 const response=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:'Bearer '+env.RESEND_API_KEY,'Content-Type':'application/json'},body:JSON.stringify({from:env.EMAIL_FROM,to:[to],subject,html})});
 return {configured:true,ok:response.ok};
}
export function emailShell(title:string,body:string){
 return '<div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;padding:28px;color:#17372c"><div style="background:#0b493a;color:white;padding:18px 22px;border-radius:14px;font-weight:800">GeStock</div><h2>'+title+'</h2>'+body+'<p style="color:#718078;font-size:12px;margin-top:28px">Si vous n’êtes pas à l’origine de cette demande, ignorez ce message.</p></div>';
}