import { drizzle } from 'drizzle-orm/node-postgres';
import { Pool } from 'pg';
import * as schema from '../schema.js';
const connectionString=process.env.DATABASE_URL;
if(!connectionString)throw new Error('DATABASE_URL is required');
const pool=new Pool({connectionString,max:5,ssl:{rejectUnauthorized:true}});
export const db=drizzle(pool,{schema});
