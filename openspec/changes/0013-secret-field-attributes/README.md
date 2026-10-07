# 0013: Attribute-Declared Secret Fields

A module author marks a config field as a secret once. The deployer chooses how to supply it in each environment. Plaintext never enters the render.

## Why

Today a secret travels as plain text through the whole render. The author states where a secret goes in two places, and nothing checks that they agree. Three parts of the system each work out the Secret's name their own way, so an environment variable and a volume can point at different objects.

## What changes

- The author marks the field with an attribute that names the Secret and the key it belongs in.
- The deployer fills the field with a literal, a reference to an existing Secret, or a named secret source.
- The kernel finds every secret from the schema and replaces it with a reference before render.
- The kernel alone names each Secret object, so every consumer reads the same name.
- Mistakes stop the render: a forgotten mark, a malformed value, an unfulfilled secret.

## What this is not

- Not cryptography. OPM calls SOPS where the CLI reads and writes files, and ships no cipher code.
- Not a Vault, external-secrets or sealed-secrets integration. The design allows them; they are later catalogs.
- Not secret rotation. A secret is resolved once per render.

## Example

```cue
// author, once, in the published module
#config: db: password: #Secret @opm(secret, group=db-creds, key=password)

// deployer, per environment
values: db: password: {value: "hunter2"}                           // a literal
values: db: password: {ref: "existing-db-creds", key: "password"}  // an existing Secret
```

## Go deeper

| You want to know | Read |
| --- | --- |
| Why each choice was made, and what was rejected | [decisions.md](decisions.md) |
| Exactly what must hold, with citable ids | [specs/](specs/) |
| The proof behind a claim | [evidence/](evidence/) |
| Affected repos and dependencies | [config.yaml](config.yaml) |
| What has shipped | [delivery.yaml](delivery.yaml), or `task delivery ID=0013` |
