#!/usr/bin/env node

import {readFile} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';

if (process.argv.length !== 2) {
  throw new Error('The Dexie dependency resolver does not accept arguments.');
}

const minimumAgeDays = Number(
  process.env.CHAINMAN_MINIMUM_RELEASE_AGE_DAYS ?? '30',
);
if (!Number.isInteger(minimumAgeDays) || minimumAgeDays < 0) {
  throw new Error('CHAINMAN_MINIMUM_RELEASE_AGE_DAYS must be a nonnegative integer.');
}

const response = await fetch('https://registry.npmjs.org/dexie', {
  headers: {accept: 'application/json'},
});
if (!response.ok) {
  throw new Error(`Unable to read Dexie registry metadata: ${response.status}.`);
}
const metadata = await response.json();
const cutoff = Date.now() - minimumAgeDays * 24 * 60 * 60 * 1000;
const stableVersion = /^\d+\.\d+\.\d+$/u;
const compare = (left, right) => {
  const a = left.split('.').map(Number);
  const b = right.split('.').map(Number);
  for (let i = 0; i < 3; i += 1) {
    if (a[i] !== b[i]) return a[i] - b[i];
  }
  return 0;
};
const eligible = Object.keys(metadata.versions ?? {})
  .filter(version => {
    const published = Date.parse(metadata.time?.[version] ?? '');
    return stableVersion.test(version) && Number.isFinite(published) && published <= cutoff;
  })
  .sort(compare);
const selected = eligible.at(-1);
if (!selected) {
  throw new Error(`No stable Dexie release is at least ${minimumAgeDays} days old.`);
}

const manifest = JSON.parse(await readFile('package.json', 'utf8'));
const current = manifest.devDependencies?.dexie;
if (current === selected) {
  console.log(`Dexie ${selected} is already the newest eligible stable release.`);
} else {
  console.log(`Updating Dexie from ${current ?? 'missing'} to eligible release ${selected}.`);
  const install = spawnSync(
    'npm',
    ['install', `dexie@${selected}`, '--save-dev', '--save-exact', '--ignore-scripts'],
    {stdio: 'inherit'},
  );
  if (install.status !== 0) process.exit(install.status ?? 1);
}

const bundle = spawnSync('just', ['bundle'], {stdio: 'inherit'});
process.exit(bundle.status ?? 1);
