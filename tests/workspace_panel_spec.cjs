const assert = require('node:assert/strict');
const { filterEntries, selectedEntry, previewRects } = require('../Hammerspoon/TheseusWorkspace.spoon/workspace_panel.js');
let assertions = 0;
const check = (actual, expected) => { assert.deepEqual(actual, expected); assertions++; };
const entries = [
  { name: 'Claude Workspace', summary: 'Claude, Finder × 2, Ghostty, Safari' },
  { name: 'CLI Workspace', summary: 'Finder × 2, Ghostty, Safari' },
  { name: 'GPT Workspace', summary: 'ChatGPT, Finder × 2, Ghostty, Safari' },
  { name: '<script>not HTML</script>', summary: 'A "quoted" app' },
];
check(filterEntries(entries, '  gPt  '), [entries[2]]);
check(filterEntries(entries, 'FINDER'), entries.slice(0, 3));
check(filterEntries(entries, 'does not exist'), []);
check(filterEntries(entries, ''), entries);
check(filterEntries(entries, '<script>'), [entries[3]]);
check(selectedEntry(entries, 'GPT Workspace'), entries[2]);
check(selectedEntry(entries, 'Missing'), entries[0]);
check(selectedEntry([], 'Missing'), null);
const rectangles = [{ x: .25, y: .5, w: .25, h: .5, appName: 'Ghostty', ordinal: 1 }];
const original = structuredClone(rectangles);
check(previewRects(rectangles, 2), [{ x: 40.9, y: 40.9, w: 38.2, h: 38.2, appName: 'Ghostty', ordinal: 1 }]);
check(rectangles, original);
const tiny = previewRects([{ x: 0, y: 0, w: .001, h: .001 }], 1)[0];
check(tiny.w > 0 && tiny.h > 0, true);
check(previewRects([], 16 / 9), []);
console.log(`workspace_panel_js: ${assertions} assertions passed`);
