// Execute the preview's actual script with a minimal DOM; no browser or game is started.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
class Element {
  constructor(tag) { this.tag = tag; this.children = []; this.textContent = ''; }
  appendChild(child) { this.children.push(child); return child; }
  replaceChildren(...children) { this.children = children; }
  setAttribute(key, value) { this[key] = value; }
  querySelector(key) { return elements[key]; }
}
const elements = Object.fromEntries(['#tree', '#status', '#reset'].map(id => [id, new Element('div')]));
const root = new Element('main');
const document = { getElementById: id => {
  assert.equal(id, 'crafttrail-preview'); return root;
}, createElement: tag => new Element(tag) };
const html = fs.readFileSync(path.join(__dirname, '../docs/engineering-preview.html'), 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
vm.runInNewContext(script, {document});
function all(node) { return [node, ...node.children.flatMap(all)]; }
function button(name) { return all(elements['#tree']).find(node => node['aria-label'] === 'Craft one ' + name); }
assert.equal(button('Fire Goggles').disabled, true);
assert.equal(button('Green Tinted Goggles').disabled, true);
assert.equal(button('Flying Tiger Goggles').disabled, false);
button('Flying Tiger Goggles').onclick();
assert.equal(button('Green Tinted Goggles').disabled, false);
assert.equal(button('Flying Tiger Goggles').disabled, true);
button('Green Tinted Goggles').onclick();
assert.equal(button('Fire Goggles').disabled, false);
button('Fire Goggles').onclick();
assert.match(elements['#status'].textContent, /crafted Fire Goggles/);
assert(all(elements['#tree']).some(node => node.textContent === '1 / 1'));
elements['#reset'].onclick();
assert.equal(button('Flying Tiger Goggles').disabled, false);
assert.equal(button('Fire Goggles').disabled, true);
console.log('Engineering preview script passed: leaf-to-root crafting, inventory consumption, parent states and reset.');
