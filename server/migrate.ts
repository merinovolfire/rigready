import {readFile} from 'node:fs/promises';import {pool} from './db.js';const sql=await readFile('db/schema.sql','utf8');await pool.query(sql);console.log('Schema migrated');await pool.end();
