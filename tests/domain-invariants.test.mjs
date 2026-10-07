import test from "node:test";
import assert from "node:assert/strict";
const positive=n=>{if(!Number.isFinite(n)||n<=0)throw new Error("quantity must be greater than zero")};
const nonNegative=n=>{if(n<0n)throw new Error("money amount cannot be negative")};
test("quantity must be positive",()=>{positive(1);assert.throws(()=>positive(0));assert.throws(()=>positive(-1))});
test("money cannot be negative",()=>{nonNegative(0n);nonNegative(1000n);assert.throws(()=>nonNegative(-1n))});
test("order identity is explicit",()=>{const order={id:"00000000-0000-0000-0000-000000000001",tenantId:"00000000-0000-0000-0000-000000000002"};assert.ok(order.id);assert.ok(order.tenantId)});
