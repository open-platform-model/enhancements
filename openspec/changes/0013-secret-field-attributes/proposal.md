# 0013: Attribute-Declared Secret Fields

An author marks a sensitive field once, with a CUE attribute. The deployer chooses, per environment, how the value is supplied. OPM rewrites every secret to a reference before render, so plaintext reaches only the object that stores it.

## Why

Today a secret travels as plain text through the whole render. The routing that says which Secret object a key belongs in is written twice by hand, once on the field and once in a map, and nothing checks that the two agree. Three code paths compute the same object name and disagree.

## What Changes

- An author declares a secret with one attribute and the secret type. The routing is stated once.
- A deployer supplies a literal, a reference to an existing Secret, or a named secret source, per environment, with no republish of the module.
- At render every secret is a reference. The supplied value never enters the rendered component graph.
- A platform installs secret sources as catalogs. The first-party catalog ships the literal one.
- A mistake fails loudly. A malformed or missing secret fails validation, and no error carries a secret value.

## What this is not

- Not cryptography. SOPS encrypts at the file edge, and OPM ships no cipher.
- Not an external-store, Vault, sealed-secret or CSI source. Those are later catalogs.
- Not rotation, leasing or dynamic secrets. A secret is resolved once per render.
- Not protection of a literal inside an instance resource. It is plaintext at rest, documented.
- Not the encryption of an exported instance. That belongs to enhancement 0014.

## Example

```cue
// the author, once, in the published module
#config: db: password: #Secret @opm(secret, group=db-creds, key=password)

// the deployer, per environment
values: db: password: {value: "hunter2"}
values: db: password: {ref: "existing-db-creds", key: "password"}
```

## Capabilities

- **New:** `secret-declaration`, `secret-resolution`, `secret-sources`, `secret-tooling`

## Impact

- **Module authors** replace the hand-written secret map with one attribute. Instance files that supply a literal do not change.
- **Platform teams** enable one catalog for each secret source they want.
- **Seven repos** change: core, library, catalog_opm, cli, opm-operator, modules and opmodel.dev. The change is breaking: core withdraws published definitions.

## Open questions

- Blocking: When a secret field copies another secret field, does the copy get its own object entry, or share the entry of the field it copies? A module that needs such a copy would settle it.
