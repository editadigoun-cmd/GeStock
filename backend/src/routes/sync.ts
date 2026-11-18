import { Hono } from 'hono';
import type { AppEnv } from '../middleware/auth.js';
export const syncRoutes=new Hono<AppEnv>();
syncRoutes.post('/batch',(c)=>c.json({error:'SYNC_PROCESSOR_NOT_READY',message:'La synchronisation serveur n’est pas encore activée. Les opérations restent dans la file locale de l’appareil.'},501));
