const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const fs = require('node:fs');
const [helper, referencePath] = process.argv.slice(2);
function call(args) {
  const result = spawnSync(helper, args, {encoding:'utf8', timeout:5000});
  assert.equal(result.status, 0, `helper failed: ${result.stderr || result.stdout}`);
  const value = JSON.parse(result.stdout);
  assert.equal(value.ok, true);
  return value;
}
const baseline = JSON.parse(fs.readFileSync(referencePath, 'utf8'));
assert.equal(baseline.stable, true);
const native = call(['snapshot']);
assert.equal(native.focusedSpaceID, baseline.focusedSpaceID);
assert.equal(native.displays.length, baseline.displays.length);
let spaces = 0, checkedWindows = 0, referenceWindowIDs = 0;
for (const display of baseline.displays) {
  const match = native.displays.find(d => d.display === display.display);
  assert.ok(match, 'display UUID absent');
  assert.equal(match.activeSpaceID, display.activeSpaceID);
  assert.deepEqual(match.spaces.map(s => [s.id,s.type]), display.spaces.map(s => [s.id,s.type]));
  for (const space of display.spaces) {
    const found = match.spaces.find(s => s.id === space.id);
    // Hammerspoon removes some of its own non-window canvas IDs from the raw list.
    for (const wid of space.windowIDs) assert.ok(found.windowIDs.includes(wid), 'reference window absent');
    referenceWindowIDs += space.windowIDs.length;
    spaces++;
  }
}
for (const window of baseline.windows) {
  const result = call(['window-spaces',window.windowID]);
  assert.deepEqual(result.spaceIDs.toSorted(), window.spaceIDs.toSorted());
  checkedWindows++;
}
assert.equal(call(['snapshot']).focusedSpaceID, baseline.focusedSpaceID);
console.log(JSON.stringify({ok:true,displays:native.displays.length,spaces,referenceWindowIDs,checkedWindows,
  displayOrderTypesAndActiveMatch:true,standardWindowMembershipMatch:true,activeSpaceUnchanged:true}));
