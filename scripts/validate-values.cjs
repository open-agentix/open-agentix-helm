#!/usr/bin/env node
// Offline check: validates values.yaml merged with each given values file against
// values.schema.json, the same way `helm lint/template` does. Needs the npm packages `ajv` (v8)
// and `yaml` resolvable via NODE_PATH; exits 0 with a notice when they are not available
// (CI relies on helm's built-in schema validation instead).
'use strict';
const fs = require('node:fs');
const path = require('node:path');

let Ajv, YAML;
try {
  Ajv = require('ajv');
  YAML = require('yaml');
} catch {
  console.log('validate-values: ajv/yaml not resolvable (set NODE_PATH) - skipped, helm validates in CI');
  process.exit(0);
}

const chart = path.resolve(process.argv[2] ?? 'charts/open-agentix');
const files = process.argv.slice(3);
const schema = JSON.parse(fs.readFileSync(path.join(chart, 'values.schema.json'), 'utf8'));
const defaults = YAML.parse(fs.readFileSync(path.join(chart, 'values.yaml'), 'utf8'));
const ajv = new (Ajv.default ?? Ajv)({ allErrors: true, strict: false });
const validate = ajv.compile(schema);

const isObj = (v) => v && typeof v === 'object' && !Array.isArray(v);
function merge(a, b) {
  const out = { ...a };
  for (const [k, v] of Object.entries(b ?? {})) {
    if (v === null) delete out[k]; // helm semantics: null removes a default
    else out[k] = isObj(v) && isObj(a?.[k]) ? merge(a[k], v) : v;
  }
  return out;
}

let failed = 0;
for (const f of [null, ...files]) {
  const values = f ? merge(defaults, YAML.parse(fs.readFileSync(f, 'utf8'))) : defaults;
  const ok = validate(values);
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${f ?? 'values.yaml (defaults)'}`);
  if (!ok) {
    failed++;
    for (const e of validate.errors) console.log(`     ${e.instancePath || '/'} ${e.message} ${JSON.stringify(e.params)}`);
  }
}
process.exit(failed ? 1 : 0);
