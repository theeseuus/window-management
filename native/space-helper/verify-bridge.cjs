// CLI/safety checks only. No valid read or move command is dispatched.
const assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const [helper,host]=process.argv.slice(2);
function call(args,status) {
  const result=spawnSync(helper,args,{encoding:'utf8',timeout:5000});
  assert.equal(result.error,undefined);
  assert.equal(result.status,status,result.stdout+result.stderr);
  return result.stdout ? JSON.parse(result.stdout) : null;
}
const help=call(['help'],0);
assert.equal(help.existingWindowTargetsAllowed,false);
assert.equal(help.requestAccessibilityPermission,false);
assert.equal(help.rexCreationReceiptRequired,true);
for (const args of [[],['bridge-query','extra'],['move-window','1','2'],
  ['bridge-probe-own','1','1'],['bridge-probe-foreign','0','2'],
  ['bridge-probe-foreign','-1','2'],['bridge-probe-own','1x','2'],
  ['bridge-probe-own','1','18446744073709551616'],
  ['bridge-probe-foreign','1','2','123'],
  ['rex-inventory','extra'], ['bridge-probe-rex','1','2'],
  ['bridge-probe-rex','1','1','receipt.json'],
  ['bridge-probe-rex','-1','2','receipt.json'],
  ['bridge-probe-rex','1','18446744073709551616','receipt.json'],
  ['bridge-restore-rex','0','receipt.json'], ['bridge-restore-rex','1']]) {
  assert.equal(call(args,64).ok,false);
}
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'bridge-guards-'));
try {
  const report=path.join(temp,'report.json');
  call(['help','--report',report],0);
  const saved=fs.readFileSync(report,'utf8');
  assert.equal(JSON.parse(saved).ok,true);
  call(['help','--report',report],73);
  assert.equal(fs.readFileSync(report,'utf8'),saved,'existing report overwritten');
  const invalid=path.join(temp,'invalid.json');
  call(['move-window','--report',invalid],64);
  assert.equal(fs.existsSync(invalid),false,'invalid command created report');
  const symlink=path.join(temp,'symlink.json');
  fs.symlinkSync(report,symlink);
  call(['help','--report',symlink],73);
  assert.equal(fs.readFileSync(report,'utf8'),saved,'symlink target modified');
} finally { fs.rmSync(temp,{recursive:true}); }
const invalidHost=spawnSync(host,[],{encoding:'utf8',timeout:5000});
assert.equal(invalidHost.status,64);
console.log('bridge CLI: invalid targets, extra arguments, report overwrite/symlink protection passed; no window created');
