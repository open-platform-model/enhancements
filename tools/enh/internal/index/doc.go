// Package index writes the three kinds of generated files of the enhancements
// repo (design part two, section 4.4): the README.md of each entry, INDEX.md
// and GRAPH.md. It also tells whether they are fresh.
//
// Every function reads the repo through an fs.FS rooted at the repo root and
// never runs git, reads the clock or touches the network. The output is a pure
// function of the tree: sorted everywhere, LF line ends, no date that is not
// read from a file. A new-layout entry has no `updated` field, so nothing here
// writes a modification date.
//
// The package never writes under openspec/specs/: that folder changes only
// when an entry is delivered.
package index
