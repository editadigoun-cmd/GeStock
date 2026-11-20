import test from 'node:test';
import assert from 'node:assert/strict';

const defaults: Record<string,string[]> = {
 owner: ['stock.read','stock.write','employees.manage'],
 manager: ['stock.read','stock.write','employees.manage'],
 cashier: ['stock.read'],
 staff: ['stock.read'],
};
function allowed(role:string, permissions:Record<string,unknown>|null, key:string):boolean {
 if (permissions && typeof permissions[key] === 'boolean') return permissions[key] === true;
 return (defaults[role] ?? []).includes(key);
}
test('role defaults follow least privilege',()=>{
 assert.equal(allowed('owner',null,'employees.manage'),true);
 assert.equal(allowed('manager',null,'stock.write'),true);
 assert.equal(allowed('cashier',null,'stock.write'),false);
 assert.equal(allowed('staff',null,'stock.write'),false);
 assert.equal(allowed('unknown',null,'stock.read'),false);
});
test('explicit business permission overrides role default',()=>{
 assert.equal(allowed('staff',{'stock.write':true},'stock.write'),true);
 assert.equal(allowed('manager',{'stock.write':false},'stock.write'),false);
});
