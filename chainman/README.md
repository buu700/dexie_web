# Chainman configuration

[`chainman.toml`](../chainman.toml) is the module index. Each file below is
ordinary schema-3 TOML; all paths remain relative to the repository root.

- [environment.toml](environment.toml)
- [services.toml](services.toml)
- [setup.toml](setup.toml)
- [tasks.toml](tasks.toml)
- [updates.toml](updates.toml)

Keep each setting in one file. Duplicate scalar or array declarations fail;
include order does not override values. Templates provide intentional inheritance.
Edits to any included file invalidate the corresponding readiness fingerprints.

```sh
just chainman config validate
just chainman config show --json
just chainman explain check --json
```

The JSON output includes `files` and `field_sources` for locating declarations.
Ordinary runtime updates change the Git pin; these modules remain project-owned.
Reconciliation outputs must name the module they actually edit.
