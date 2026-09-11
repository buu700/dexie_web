import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  chmodSync,
  copyFileSync,
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

const opaqueArguments = [
  "two words",
  "",
  "single'quote",
  'double"quote',
  "$literal",
  "$(touch unexpected-execution)",
  "`touch unexpected-execution`",
  "; touch unexpected-execution",
  "line\nbreak",
  "Unicode λ",
  "--option",
];
const commandName = 'named "command" $(touch unexpected-execution)';

for (const [recipe, supplied, prefix] of [
  ["exec", opaqueArguments, ["exec", "--profile", "default", "--"]],
  ["run", [commandName, ...opaqueArguments], ["run", commandName]],
  ["deps-update", opaqueArguments, ["deps-update"]],
  ["chainman-update", opaqueArguments, ["chainman-update"]],
  ["e2e", opaqueArguments, ["run", "e2e", "--"]],
]) {
  for (const [mode, exit] of [
    [undefined, 0],
    ["container-nix", 0],
    [undefined, 41],
  ]) {
    test(`${recipe} preserves argv, mode ${mode ?? "default"}, and exit ${exit}`, (t) => {
      const root = mkdtempSync(join(tmpdir(), "dexie Just argv "));
      t.after(() => rmSync(root, { recursive: true, force: true }));
      const project = join(root, "project with spaces");
      mkdirSync(join(project, "scripts"), { recursive: true });
      copyFileSync(
        new URL("../justfile", import.meta.url),
        join(project, "justfile"),
      );
      const launcher = join(project, "scripts", "chainman.sh");
      writeFileSync(
        launcher,
        [
          "#!/usr/bin/env bash",
          "set -euo pipefail",
          'printf \'%s\\0\' "$CHAINMAN_MODE" "$@" >"$JUST_ARGV_CAPTURE"',
          'exit "$JUST_ARGV_EXIT"',
          "",
        ].join("\n"),
      );
      chmodSync(launcher, 0o755);
      const capture = join(root, "captured.bin");
      rmSync(capture, { force: true });
      const env = {
        ...process.env,
        JUST_ARGV_CAPTURE: capture,
        JUST_ARGV_EXIT: String(exit),
      };
      delete env.CHAINMAN_MODE;
      if (mode !== undefined) env.CHAINMAN_MODE = mode;
      const result = spawnSync(
        "just",
        ["--justfile", join(project, "justfile"), recipe, ...supplied],
        {
          cwd: root,
          env,
          encoding: "utf8",
        },
      );
      assert.equal(result.error, undefined);
      assert.equal(result.status, exit, result.stderr);
      assert.deepEqual(
        readFileSync(capture),
        Buffer.from(
          [mode ?? "host-nix", ...prefix, ...opaqueArguments, ""].join("\0"),
        ),
      );
      for (const path of [project, root])
        assert.equal(existsSync(join(path, "unexpected-execution")), false);
    });
  }
}
