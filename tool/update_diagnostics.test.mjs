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

const script = fileURLToPath(
  new URL("./collect-update-diagnostics.sh", import.meta.url),
);

function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), "dexie update diagnostics "));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const cache = join(root, "cache with spaces");
  const output = join(root, "reports with spaces");
  const collect = () =>
    spawnSync("bash", [script, output], {
      cwd: root,
      env: { ...process.env, XDG_CACHE_HOME: cache },
      encoding: "utf8",
    });
  return { root, cache, output, collect };
}

for (const layout of ["", "v1"]) {
  test(`collects ignored reports and a patch from a retained ${layout || "legacy"} candidate`, (t) => {
    const { cache, output, collect } = fixture(t);
    const candidate = join(
      cache,
      "chainman",
      "updates",
      layout,
      "candidate.fixture",
      "candidate",
    );
    mkdirSync(candidate, { recursive: true });
    const git = (...args) => {
      const result = spawnSync(
        "git",
        [
          "-c",
          "core.hooksPath=/dev/null",
          "-c",
          "commit.gpgsign=false",
          "-c",
          "user.name=Fixture",
          "-c",
          "user.email=fixture@example.test",
          ...args,
        ],
        {
          cwd: candidate,
          encoding: "utf8",
        },
      );
      assert.equal(result.status, 0, result.stderr);
    };
    git("init", "--initial-branch=fixture");
    writeFileSync(
      join(candidate, ".gitignore"),
      "test-results/\nexample/test-results/\n",
    );
    writeFileSync(join(candidate, "package.json"), '{"before":true}\n');
    git("add", ".gitignore", "package.json");
    git("commit", "-m", "Fixture baseline");
    writeFileSync(join(candidate, "package.json"), '{"after":true}\n');
    mkdirSync(join(candidate, "example", "test-results"), { recursive: true });
    mkdirSync(join(candidate, "test-results"));
    writeFileSync(
      join(candidate, "example", "test-results", "integration.json"),
      '{"failure":"missing case"}\n',
    );
    writeFileSync(
      join(candidate, "example", "test-results", "e2e.log"),
      "Browser failure\n",
    );
    writeFileSync(
      join(candidate, "test-results", "verify.log"),
      "Unit test failure\n",
    );
    for (let attempt = 0; attempt < 2; attempt++) {
      const result = collect();
      assert.equal(result.status, 0, result.stderr);
      const archived = join(output, "candidates", "candidate.fixture");
      assert.match(
        readFileSync(join(archived, "deps-update.patch"), "utf8"),
        /\+\{"after":true\}/,
      );
      assert.equal(
        readFileSync(
          join(archived, "example", "test-results", "integration.json"),
          "utf8",
        ),
        '{"failure":"missing case"}\n',
      );
      assert.equal(
        readFileSync(
          join(archived, "example", "test-results", "e2e.log"),
          "utf8",
        ),
        "Browser failure\n",
      );
      assert.equal(
        readFileSync(join(archived, "test-results", "verify.log"), "utf8"),
        "Unit test failure\n",
      );
      assert.equal(
        existsSync(join(archived, "example", "test-results", "test-results")),
        false,
      );
    }
  });
}

test("collects diagnostics before a candidate Git repository is ready", (t) => {
  const { cache, output, collect } = fixture(t);
  const candidate = join(
    cache,
    "chainman",
    "updates",
    "candidate.incomplete",
    "candidate",
  );
  mkdirSync(join(candidate, "test-results"), { recursive: true });
  writeFileSync(
    join(candidate, "test-results", "verify.log"),
    "Early failure\n",
  );
  const result = collect();
  assert.equal(result.status, 0, result.stderr);
  const archived = join(output, "candidates", "candidate.incomplete");
  assert.equal(
    readFileSync(join(archived, "test-results", "verify.log"), "utf8"),
    "Early failure\n",
  );
  assert.equal(existsSync(join(archived, "deps-update.patch")), false);
});

test("missing update cache is harmless", (t) => {
  const { output, collect } = fixture(t);
  const result = collect();
  assert.equal(result.status, 0, result.stderr);
  assert.equal(existsSync(output), false);
});
