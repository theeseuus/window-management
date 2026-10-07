(() => {
  'use strict';
  const filterEntries = (entries, query) => {
    const term = query.trim().toLocaleLowerCase();
    return entries.filter(entry => `${entry.name} ${entry.summary}`.toLocaleLowerCase().includes(term));
  };
  const selectedEntry = (entries, name) => entries.find(entry => entry.name === name) || entries[0] || null;
  const previewRects = (rectangles, aspectRatio) => {
    const width = 160, height = width / aspectRatio;
    return rectangles.map(rect => {
      const w = rect.w * width, h = rect.h * height;
      const inset = Math.min(.9, w / 6, h / 6);
      return { x: rect.x * width + inset, y: rect.y * height + inset,
        w: w - inset * 2, h: h - inset * 2, appName: rect.appName, ordinal: rect.ordinal };
    });
  };
  // No DOM dependency is needed for the deterministic filtering/geometry tests.
  if (typeof module !== 'undefined') module.exports = { filterEntries, selectedEntry, previewRects };
  if (typeof document === 'undefined') return;

  const $ = id => document.getElementById(id);
  let model = { state: 'loading', revision: 0, entries: [], aspectRatio: 16 / 9 };
  let selection = null, visibleEntries = [], menuName = null;
  const post = (action, extra = {}) => window.webkit.messageHandlers.TheseusWorkspacePanel.postMessage({
    action, revision: model.revision, ...extra,
  });
  const count = value => `${value} ${value === 1 ? 'window' : 'windows'} captured`;
  const hideMenu = () => { $('context-menu').hidden = true; menuName = null; };

  function preview(entry) {
    const ns = 'http://www.w3.org/2000/svg';
    const svg = document.createElementNS(ns, 'svg');
    const ratio = Number.isFinite(model.aspectRatio) && model.aspectRatio > 0 ? model.aspectRatio : 16 / 9;
    const height = 160 / ratio;
    svg.setAttribute('viewBox', `-4 -4 168 ${height + 8}`);
    svg.setAttribute('class', 'layout-preview');
    svg.setAttribute('role', 'img');
    svg.setAttribute('aria-label', `${entry.windowCount} windows in saved layout`);
    const rectangle = (x, y, w, h, radius, strokeWidth) => {
      const node = document.createElementNS(ns, 'rect');
      for (const [key, value] of Object.entries({ x, y, width: w, height: h, rx: radius,
        fill: 'none', stroke: 'currentColor', 'stroke-width': strokeWidth })) node.setAttribute(key, value);
      svg.append(node);
      return node;
    };
    rectangle(-3, -3, 166, height + 6, 5, 1.2);
    for (const rect of previewRects(entry.rectangles, ratio)) {
      const node = rectangle(rect.x, rect.y, rect.w, rect.h, Math.min(2, rect.w / 4, rect.h / 4), 1);
      const title = document.createElementNS(ns, 'title');
      title.textContent = `${rect.appName}, window ${rect.ordinal}`;
      node.append(title);
    }
    return svg;
  }

  function updateSelection(name, scroll = false) {
    selection = selectedEntry(visibleEntries, name)?.name || null;
    for (const row of $('rows').children) {
      const selected = row.dataset.name === selection;
      row.classList.toggle('selected', selected);
      row.setAttribute('aria-selected', String(selected));
      row.tabIndex = selected ? 0 : -1;
      if (selected && scroll) row.scrollIntoView({ block: 'nearest' });
    }
    const disabled = !selection;
    $('delete').disabled = disabled;
    $('secondary').disabled = disabled;
    $('primary').disabled = disabled;
  }

  function openMenu(name, x, y) {
    updateSelection(name);
    menuName = name;
    const menu = $('context-menu');
    menu.hidden = false;
    menu.style.left = `${Math.max(8, Math.min(x, innerWidth - menu.offsetWidth - 8))}px`;
    menu.style.top = `${Math.max(8, Math.min(y, innerHeight - menu.offsetHeight - 8))}px`;
    $('menu-restore').focus();
  }

  function renderLibrary() {
    visibleEntries = filterEntries(model.entries || [], $('search').value);
    const chosen = selectedEntry(visibleEntries, model.selectedName || selection);
    const rows = $('rows');
    rows.replaceChildren();
    for (const entry of visibleEntries) {
      const row = document.createElement('div');
      row.className = 'layout-row';
      row.dataset.name = entry.name;
      row.setAttribute('role', 'option');
      row.setAttribute('aria-label', `${entry.name}, ${entry.windowCount} windows, ${entry.summary}`);
      const thumb = document.createElement('div');
      thumb.className = 'thumbnail'; thumb.append(preview(entry));
      const text = document.createElement('div'); text.className = 'row-text';
      for (const [className, value] of [['row-title', entry.name],
        ['row-count', `${entry.windowCount} ${entry.windowCount === 1 ? 'window' : 'windows'}`],
        ['row-apps', entry.summary]]) {
        const line = document.createElement('p'); line.className = className;
        line.textContent = value; text.append(line);
      }
      const menu = document.createElement('button');
      menu.className = 'row-menu'; menu.type = 'button'; menu.textContent = '…';
      menu.setAttribute('aria-label', `Actions for ${entry.name}`);
      menu.setAttribute('aria-haspopup', 'menu');
      menu.addEventListener('click', event => {
        event.stopPropagation(); const box = menu.getBoundingClientRect(); openMenu(entry.name, box.right, box.bottom);
      });
      row.append(thumb, text, menu);
      row.addEventListener('click', () => updateSelection(entry.name));
      row.addEventListener('dblclick', event => {
        if (event.target.closest('button')) return;
        post('restore', { name: entry.name });
      });
      row.addEventListener('contextmenu', event => {
        event.preventDefault(); openMenu(entry.name, event.clientX, event.clientY);
      });
      rows.append(row);
    }
    const hasEntries = (model.entries || []).length > 0;
    $('empty').hidden = visibleEntries.length > 0;
    $('empty-title').textContent = hasEntries ? 'No matching layouts' : 'No saved layouts yet';
    $('empty-detail').textContent = hasEntries ? 'Try another name or application.' : 'Arrange your windows, then choose Capture… to save this Space’s layout.';
    updateSelection(chosen?.name, !!model.selectedName);
  }

  function labelButton(id, text, shortcut) {
    $(id).replaceChildren(document.createTextNode(text));
    if (shortcut) { const key = document.createElement('kbd'); key.textContent = shortcut; $(id).append(key); }
  }

  function updateSave() {
    if (model.state === 'ready') $('primary').disabled = !$('name').value.trim();
  }

  window.setWorkspaceState = data => {
    const previous = model.state;
    model = data;
    hideMenu();
    const library = model.state === 'library';
    const confirmation = model.state === 'confirm-delete' || model.state === 'confirm-replace';
    $('library').hidden = !library;
    $('capture').hidden = library || confirmation;
    $('confirmation').hidden = !confirmation;
    $('search-box').hidden = !library;
    $('capture-button').hidden = !library;
    $('delete').hidden = !library;
    $('error').textContent = model.error || '';
    $('error').hidden = !model.error;
    $('primary').classList.toggle('destructive', model.state === 'confirm-delete');
    $('primary').classList.toggle('primary', model.state !== 'confirm-delete');
    for (const key of ['search', 'delete']) {
      const url = model.icons?.[key];
      if (url && /^data:image\//.test(url)) { $(`${key}-icon`).src = url; $(`${key}-icon`).hidden = false; }
    }
    $('delete-label').hidden = !!model.icons?.delete;
    if (library) {
      if (model.clearQuery) $('search').value = '';
      labelButton('secondary', 'Restore', '↩'); labelButton('primary', 'Establish here', '⌘↩');
      $('secondary-help').textContent = 'Arrange existing windows';
      $('primary-help').textContent = 'Open missing apps and windows';
      renderLibrary();
      if (previous !== 'library') $('search').focus();
    } else if (confirmation) {
      $('confirm-title').textContent = model.state === 'confirm-delete' ? 'Delete saved layout?' : 'Replace saved layout?';
      $('confirm-detail').textContent = model.message;
      labelButton('secondary', 'Cancel', 'Esc');
      labelButton('primary', model.state === 'confirm-delete' ? 'Delete layout' : 'Replace layout');
      $('secondary-help').textContent = 'Keep the saved layout';
      $('primary-help').textContent = model.state === 'confirm-delete' ? 'Remove only this recipe' : 'Save the new captured layout';
      $('secondary').disabled = false; $('primary').disabled = false;
      $('secondary').focus();
    } else {
      const ready = model.state === 'ready';
      $('capture-status').textContent = model.message || (model.capture ? count(model.capture.windowCount) : 'Capturing windows…');
      $('name').disabled = !ready;
      if (model.state === 'capturing' && previous !== 'capturing') $('name').value = '';
      $('capture-summary').hidden = !model.capture;
      if (model.capture) {
        $('capture-preview').replaceChildren(preview(model.capture));
        $('included-apps').replaceChildren();
        for (const app of model.capture.applications) { const li = document.createElement('li'); li.textContent = app; $('included-apps').append(li); }
      }
      labelButton('secondary', 'Cancel', 'Esc'); labelButton('primary', 'Save layout', '↩');
      $('secondary-help').textContent = 'Return to saved layouts';
      $('primary-help').textContent = 'Save this captured layout';
      $('secondary').disabled = model.state === 'saving';
      $('primary').disabled = !ready || !$('name').value.trim();
      if (ready && previous !== 'ready') $('name').focus();
    }
  };

  const libraryAction = action => { if (model.state === 'library' && selection) post(action, { name: selection }); };
  $('search').addEventListener('input', () => { hideMenu(); model.selectedName = null; renderLibrary(); });
  $('capture-button').addEventListener('click', () => post('capture'));
  $('delete').addEventListener('click', () => libraryAction('delete'));
  $('name').addEventListener('input', updateSave);
  $('capture-form').addEventListener('submit', event => { event.preventDefault(); if (model.state === 'ready' && !$('primary').disabled) post('save', { name: $('name').value }); });
  $('secondary').addEventListener('click', () => {
    if (model.state === 'library') libraryAction('restore'); else post('cancel');
  });
  $('primary').addEventListener('click', () => {
    if ($('primary').disabled) return;
    if (model.state === 'library') libraryAction('establish');
    else if (model.state === 'confirm-delete') post('confirm-delete');
    else if (model.state === 'confirm-replace') post('confirm-replace');
    else if (model.state === 'ready') post('save', { name: $('name').value });
  });
  for (const action of ['restore', 'establish', 'delete']) $('menu-' + action).addEventListener('click', () => {
    const name = menuName; hideMenu(); if (name) post(action, { name });
  });
  document.addEventListener('click', event => { if (!event.target.closest('.context-menu, .row-menu')) hideMenu(); });
  document.addEventListener('keydown', event => {
    if (event.isComposing || event.ctrlKey || event.altKey) return;
    if (event.key === 'Escape') {
      event.preventDefault();
      if (!$('context-menu').hidden) { hideMenu(); $('search').focus(); }
      else if (model.state === 'library') post('close');
      else if (model.state !== 'saving') post('cancel');
      return;
    }
    if (model.state !== 'library') return;
    if (event.metaKey && (event.key === 'Backspace' || event.key === 'Delete')) { event.preventDefault(); libraryAction('delete'); return; }
    if (event.key === 'Enter' && (event.metaKey || event.target.tagName !== 'BUTTON')) {
      event.preventDefault(); libraryAction(event.metaKey ? 'establish' : 'restore'); return;
    }
    if (!event.metaKey && (event.key === 'ArrowDown' || event.key === 'ArrowUp') && $('context-menu').hidden) {
      event.preventDefault(); const index = visibleEntries.findIndex(entry => entry.name === selection);
      const offset = event.key === 'ArrowDown' ? 1 : -1;
      const next = visibleEntries[Math.max(0, Math.min(visibleEntries.length - 1, index + offset))];
      if (next) updateSelection(next.name, true);
    }
  });
  post('ready');
})();
