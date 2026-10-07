export function compareReconciliation(local,server){
 const fields=["transactionCount","totalMinor","paymentTotalMinor","outstandingSyncCount"];
 const mismatches=fields.filter(f=>local[f]!==server[f]);
 return {status:mismatches.length?"RECONCILIATION_REQUIRED":"PASS",mismatches};
}
