# 0013: Attribute-Declared Secret Fields

A module author marks a config field as a secret once. The deployer chooses how to supply it in each environment. Plaintext never enters the render.

## Why

Today a secret travels as plain text through the whole render. The author states where a secret goes in two places, and nothing checks that they agree. Three parts of the system each work out the Secret's name their own way, so an environment variable and a volume can point at different objects.

## What Changes

- The author marks the field with an attribute that names the Secret and the key it belongs in.
- The deployer fills the field with a literal, a reference to an existing Secret, or a named secret source.
- The kernel finds every secret from the schema and replaces it with a reference before render.
- The kernel alone names each Secret object, so every consumer reads the same name.
- Mistakes are caught early: a malformed or unfilled secret fails, and a forgotten attribute gets safe defaults.

## What this is not

- Not cryptography. OPM calls SOPS where the CLI reads and writes files, and ships no cipher code.
- Not a Vault, external-secrets or sealed-secrets integration. Those are later catalogs.
- Not secret rotation. A secret is resolved once per render.

## Example

```cue
// author, once, in the published module
#config: db: password: #Secret @opm(secret, group=db-creds, key=password)

// deployer, per environment
values: db: password: {value: "hunter2"}                           // a literal
values: db: password: {ref: "existing-db-creds", key: "password"}  // an existing Secret
```

## Capabilities

- **New:** `secrets`
- **Modified:** `instance-export`. An export now encrypts literal secrets.

## Impact

- **Module authors** mark each secret field once. A module that carries a secret as a plain string must change.
- **Deployers** keep their values files. A literal inside an instance package must move to a values file or become a reference.
- **Breaking** for `core` and the opm catalog. Seven repos ship a part; `config.yaml` lists them.
