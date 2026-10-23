// These checks never create or move windows. Live queries require --live.
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const [helper, mode] = process.argv.slice(2);
assert.ok(helper, 'usage: node verify.cjs HELPER [--live]');
assert.ok(mode === undefined || mode === '--live');
function call(args, status) {
  const result = spawnSync(helper, args, {encoding:'utf8', timeout:5000});
  assert.equal(result.error, undefined);
  assert.equal(result.status, status, result.stderr || result.stdout);
  const value = JSON.parse(result.stdout);
  assert.equal(value.schemaVersion, 1);
  assert.equal(typeof value.ok, 'boolean');
  return value;
}
assert.equal(call(['help'],0).moveOwnWindowOnly, true);
for (const args of [[], ['move','1','2'], ['snapshot','extra'],
  ['window-spaces','0'], ['window-spaces','-1'], ['window-spaces','1x'],
  ['window-spaces','4294967296'], ['window-spaces','1','extra'],
  ['probe-move','1','1'], ['probe-move','0','2'],
  ['probe-move','1','18446744073709551616'], ['probe-move','1','2','3']]) {
  const value = call(args,64);
  assert.equal(value.ok,false);
  assert.match(value.reason,/^usage:/);
}
if (mode === '--live') {
  const first = call(['snapshot'],0);
  assert.equal(first.ok,true);
  const decimal = /^[1-9][0-9]*$/;
  assert.match(first.focusedSpaceID,decimal);
  assert.ok(first.displays.length>0);
  for (const display of first.displays) {
    assert.equal(typeof display.display,'string');
    assert.ok(display.spaces.some(s=>s.id===display.activeSpaceID));
    for (const space of display.spaces) {
      assert.match(space.id,decimal);
      assert.ok(['user','fullscreen','unknown'].includes(space.type));
      assert.equal(typeof space.typeCode,'number');
      space.windowIDs.forEach(id=>assert.match(id,decimal));
    }
  }
  assert.equal(call(['snapshot'],0).focusedSpaceID,first.focusedSpaceID);
}
console.log(`native helper: CLI guards${mode ? ' and live snapshot schema' : ''} passed; no move requested`);
