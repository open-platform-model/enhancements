@if(cross)

package core

// A provider built on opm@v4 against a component on opm@v5. Evaluated only
// with -t cross, so the other cases stay readable without its error.
matchCrossMajor: _k8upV2.schedule.requiredTraits[_backupKey] & v5ComponentBackup
