// Read-only LaunchServices run. Never asks for Accessibility or creates windows.
const assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const [app]=process.argv.slice(2);
assert.ok(app,'pass BridgeProbe.app path');
const directory=fs.mkdtempSync(path.join(os.tmpdir(),'bridge-query-'));
try {
  const report=path.join(directory,'query.json');
  const result=spawnSync('/usr/bin/open',['-n','-g','-W',path.resolve(app),'--args',
    'bridge-query','--report',report],{encoding:'utf8',timeout:10000});
  assert.equal(result.error,undefined);
  assert.equal(result.status,0,result.stderr);
  const value=JSON.parse(fs.readFileSync(report,'utf8'));
  assert.equal(value.ok,true);
  assert.equal(value.topologyMatchesCAPI,true);
  assert.equal(value.windowMembershipMatchesCAPI,true);
  assert.equal(value.activeSpaceUnchanged,true);
  assert.ok(value.checkedWindows>0);
  assert.equal(typeof value.axTrusted,'boolean');
  console.log(JSON.stringify(value));
} finally { fs.rmSync(directory,{recursive:true}); }
