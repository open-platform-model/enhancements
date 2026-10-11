# Notes for the owner at accept

These notes come from the alignment of 0022 with the seeds. The old entry did not hold them as open questions, so they are not in the proposal.

- **Publish fills the version and the block.** The requirement "A version write updates the block" says a write of a new version updates the block. The old decision prose names the version option of publish as one such write. The seed requirement "The pushed bytes are the artifact directory" of `artifact-publishing` says the only change publish makes to the tree is filling an open version. If publish fills the version, the block write is a second change. The owner decides whether that seed requirement changes.
- **A repair that has nothing to write.** A refusal for a stale block names the writer command that repairs the tree. The seed requirement "Setting the declared version writes nothing" says that setting the version the identity file already declares writes no byte. With a stale block, the repair would write nothing. The owner decides which rule wins.
- **The block reading reaches every command that takes a published module.** The old text named only the instance-initialisation walk. The seed walk serves every such command, so the modified requirement applies the block reading and the non-module skip to all of them. The owner confirms the wider scope.
