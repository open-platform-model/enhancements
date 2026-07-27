// The typed-and-concrete form: the committed file keeps asserting SemVer.
// A writer that replaces the whole value silently deletes that assertion.
//
// This file is DELIBERATELY NOT `cue fmt`-clean — there are two spaces before
// each @opm() where one would do. The rewrite goes through format.Node, which
// formats the WHOLE file, so those two lines change even though the edit
// touched one. Compare catalog_concrete.cue, which is fmt-clean and produces a
// one-line diff. The lesson is a precondition, not a defect: `version set`
// should refuse, or fmt first, on a tree that is not already formatted.
package identity

#VersionType: string & =~"^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

ModulePath: "example.com/catalogs/demo@v1"  @opm(identity, owner=publish)
Version:    #VersionType & "1.2.0"          @opm(identity, owner=publish)
