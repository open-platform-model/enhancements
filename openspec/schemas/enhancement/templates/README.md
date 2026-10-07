<!-- LAYER 1: INTENT. Owner: the proposer, word for word. Reader: a developer new to this. Reading time: 2 minutes.
     Cap: 300 words, not counting the code block and the "Go deeper" table.
     Plain words. No decision numbers, no requirement ids, no type names the reader must already know. No metadata. -->

# NNNN: <Title>

<Three sentences at most. What OPM does once this lands, said so a newcomer understands it.>

## Why

<What is wrong today. Two to four sentences. Name the pain, not the mechanism.>

## What changes

- <Three to five bullets, one line each. Each is something a person can observe afterwards.>

## What this is not

- Not <X>. <One sentence on where X lives instead.>

## Example

```cue
// One small block that shows the change from the user's side.
```

## Go deeper

| You want to know | Read |
| --- | --- |
| Why each choice was made, and what was rejected | [decisions.md](decisions.md) |
| Exactly what must hold, with citable ids | [specs/](specs/) |
| The proof behind a claim | [evidence/](evidence/) |
| Affected repos and dependencies | [config.yaml](config.yaml) |
| What has shipped | [delivery.yaml](delivery.yaml), or `task delivery ID=NNNN` |
