# Class 9: documentation (`opmodel.dev`)

**Carrier:** none today; a single flat tree with a site-wide version string. **Surface:** which versions of the schema, the catalogs and the tooling a page describes. **Rule (OQ15):** every reference page states the component versions it was generated from, and the site is versioned against the tooling train (class 7) if OQ14 adopts one, with the schema and catalog versions that train pins stated on each generated page. Versioning the site per component independently is what OQ15 rejects as the alternative: three axes on one page is a matrix nobody maintains.

**Fixed refs (D10, U8).** A released version's pages are built from that version's release tag, which never moves. A fix after release lands on a `docs/vX.Y` branch created from the tag only when one is needed; the site's version list pins its commit by full SHA and is bumped by commit. A `docs/*` branch only moves forward and is never deleted.
