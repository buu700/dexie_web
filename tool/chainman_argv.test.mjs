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
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { isAbsolute, join } from "node:path";
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
// Resolve before restricting PATH, matching nix run's absolute executable launch.
function executable(name) {
  const result = spawnSync("sh", ["-c", 'command -v "$1"', "sh", name], {
    encoding: "utf8",
  });
  assert.equal(result.status, 0, result.stderr);
  const path = result.stdout.trim();
  assert.ok(isAbsolute(path), `${name} must resolve to an absolute executable`);
  return path;
}
const justExecutable = executable("just");
const bashExecutable = executable("bash");
const justfile = readFileSync(new URL("../justfile", import.meta.url), "utf8");
const aliases = [
  ...justfile.matchAll(
    /^(\S+) [*+]args:\n(?: {4}.*\n)*? {4}(?:@|exec ).+? chainman (.+) "\$@"$/gm,
  ),
]
  .filter(([, recipe]) => recipe !== "chainman")
  .map(([, recipe, prefix]) => [recipe, prefix.split(" ")]);
assert.ok(aliases.some(([recipe]) => recipe === "verify"));

for (const [recipe, prefix] of aliases) {
  const supplied = opaqueArguments;
  for (const [mode, exit] of [
    [undefined, 0],
    ["host-nix", 0],
    ["container-nix", 0],
    [undefined, 41],
  ]) {
    test(`${recipe} works without Just on PATH, mode ${mode ?? "default"}, and exit ${exit}`, (t) => {
      const root = mkdtempSync(join(tmpdir(), "dexie Just argv "));
      t.after(() => rmSync(root, { recursive: true, force: true }));
      const project = join(root, "project with spaces");
      mkdirSync(join(project, "scripts"), { recursive: true });
      copyFileSync(
        new URL("../justfile", import.meta.url),
        join(project, "justfile"),
      );
      const fixtureJustfile = join(project, "justfile");
      writeFileSync(
        fixtureJustfile,
        readFileSync(fixtureJustfile, "utf8").replace(
          /chainman \+args:\n(?: {4}.*\n)+/,
          'chainman +args:\n    #!/bin/sh\n    exec ./scripts/record-entry.sh "$@"\n',
        ),
      );
      const launcher = join(project, "scripts", "record-entry.sh");
      writeFileSync(
        launcher,
        [
          "#!/bin/sh",
          "set -eu",
          'printf \'%s\\0\' "${CHAINMAN_MODE:-}" "$@" >"$JUST_ARGV_CAPTURE"',
          'exit "$JUST_ARGV_EXIT"',
          "",
        ].join("\n"),
      );
      chmodSync(launcher, 0o755);
      const capture = join(root, "captured.bin");
      rmSync(capture, { force: true });
      const restrictedPath = join(root, "bin");
      mkdirSync(restrictedPath);
      symlinkSync(bashExecutable, join(restrictedPath, "bash"));
      assert.equal(existsSync(join(restrictedPath, "just")), false);
      const env = {
        ...process.env,
        PATH: restrictedPath,
        JUST_ARGV_CAPTURE: capture,
        JUST_ARGV_EXIT: String(exit),
      };
      delete env.CHAINMAN_MODE;
      if (mode !== undefined) env.CHAINMAN_MODE = mode;
      const result = spawnSync(
        justExecutable,
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
        Buffer.from([mode ?? "", ...prefix, ...opaqueArguments, ""].join("\0")),
      );
      for (const path of [project, root])
        assert.equal(existsSync(join(path, "unexpected-execution")), false);
    });
  }
}

test("default lists recipes without Just on PATH", (t) => {
  const root = mkdtempSync(join(tmpdir(), "dexie Just default "));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  symlinkSync(bashExecutable, join(root, "bash"));
  const result = spawnSync(
    justExecutable,
    ["--justfile", new URL("../justfile", import.meta.url).pathname],
    {
      env: { ...process.env, PATH: root },
      encoding: "utf8",
    },
  );
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /verify/);
});
