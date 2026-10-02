import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const bashExecutable = spawnSync("sh", ["-c", "command -v bash"], {
  encoding: "utf8",
}).stdout.trim();

for (const exit of [0, 41]) {
  test(`browser wrapper forwards arguments and exit ${exit}`, (t) => {
    const root = mkdtempSync(join(tmpdir(), "dexie browser wrapper "));
    t.after(() => rmSync(root, { recursive: true, force: true }));
    const bin = join(root, "bin");
    mkdirSync(bin);
    const browser = join(bin, "browser with spaces");
    writeFileSync(
      browser,
      '#!/bin/sh\ntest "$1" = --version || exit 42\necho "Fixture Chrome"\n',
      { mode: 0o755 },
    );
    writeFileSync(
      join(bin, "flutter"),
      '#!/bin/sh\nprintf \'%s\\0\' "$CHROME_EXECUTABLE" "$@" > "$CAPTURE"\nexit "$FLUTTER_EXIT"\n',
      { mode: 0o755 },
    );
    const capture = join(root, "capture");
    const args = [
      "test/unit/with spaces.dart",
      "",
      "--concurrency=1",
      "$(touch unexpected-execution)",
    ];
    const result = spawnSync(
      bashExecutable,
      [fileURLToPath(new URL("./test-web.sh", import.meta.url)), ...args],
      {
        cwd: root,
        env: {
          ...process.env,
          PATH: bin,
          CHROME_EXECUTABLE: browser,
          CAPTURE: capture,
          FLUTTER_EXIT: String(exit),
        },
        encoding: "utf8",
      },
    );
    // Use the parent's Bash path to launch while only fixture tools are on PATH.
    assert.equal(result.error, undefined);
    assert.equal(result.status, exit, result.stderr);
    assert.deepEqual(
      readFileSync(capture),
      Buffer.from(
        [
          browser,
          "test",
          "--no-pub",
          "--platform=chrome",
          "--verbose",
          "--reporter=expanded",
          ...args,
          "",
        ].join("\0"),
      ),
    );
    assert.match(result.stdout, /Fixture Chrome/);
    assert.equal(existsSync(join(root, "unexpected-execution")), false);
  });
}

test("invalid explicit browser fails before starting Flutter", (t) => {
  const root = mkdtempSync(join(tmpdir(), "dexie missing browser "));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const result = spawnSync(
    bashExecutable,
    [fileURLToPath(new URL("./test-web.sh", import.meta.url))],
    {
      env: { ...process.env, CHROME_EXECUTABLE: join(root, "missing") },
      encoding: "utf8",
    },
  );
  assert.equal(result.status, 1, result.stderr);
  assert.match(result.stderr, /No executable Chromium\/Chrome binary found/);
});
