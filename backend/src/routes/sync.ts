import { Hono } from 'hono';
import { z } from 'zod';
import { db } from '../services/db.js';
import { syncOperations } from '../schema.js';
type Vars={userId:string};
export const syncRoutes=new Hono<{Variables:Vars}>();
const batchSchema=z.object({operations:z.array(z.object({operation_key:z.string().uuid(),business_id:z.string().uuid(),device_id:z.string().uuid(),entity_type:z.enum(['product','business']),entity_id:z.string().uuid(),operation_type:z.string().min(1).max(40),payload:z.record(z.unknown())})).max(100)});
syncRoutes.post('/batch',async(c)=>{
 const parsed=batchSchema.safeParse(await c.req.json());if(!parsed.success)return c.json({error:'VALIDATION_ERROR',details:parsed.error.flatten()},422);
 // Queue intake only. No domain operation processor is enabled yet.
 const accepted=[];
 for(const op of parsed.data.operations){
  const [row]=await db.insert(syncOperations).values({businessId:op.business_id,deviceId:op.device_id,operationKey:op.operation_key,entityType:op.entity_type,entityId:op.entity_id,operationType:op.operation_type,payload:op.payload,status:'queued'}).onConflictDoNothing().returning({id:syncOperations.id});
  accepted.push({operation_key:op.operation_key,accepted:Boolean(row)});
 }
 return c.json({results:accepted,processing:'queued'});
});
