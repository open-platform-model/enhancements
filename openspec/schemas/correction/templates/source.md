# Source note: correction-<slug>

<!-- This is a correction. It brings delivered requirements in line with behaviour that ships
     today. It is not an enhancement and has no number. -->

Corrects: `<capability>`. <One sentence: what had drifted.>

## Shipped by

<!-- One row for each requirement of each delta spec, and no other row. Requirement: the name
     as in the delta (the new name for a RENAMED block). Change: MODIFIED, REMOVED, ADDED or
     RENAMED. Shipped by: `<repo>` PR <n> or `<repo>` commit <sha>, the change that made it
     true. Code read: the code that shows the text, as `path:line`; needed for MODIFIED and for
     an ADDED that does not replace a REMOVED. Never write the pipe character in a cell. -->

| Capability | Requirement | Change | Shipped by | Code read |
| --- | --- | --- | --- | --- |
| `<capability>` | <Requirement name> | MODIFIED | `<repo>` PR <n> | `<path>:<line>` |

## Left out

- <Behaviour left out, and why. A live enhancement owns it, or it does not ship.>

<!-- The sample line is the last line of this file. `task accept ID=correction-<slug>` with
     CONFIRM=1 writes it after the owner has read the sample; never write it by hand. It has the
     form `sampled: <date> <commit>`. Until then the file has no such line. -->
