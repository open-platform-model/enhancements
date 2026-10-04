package main

import (
	"fmt"
	"log"
	"net/http"
	"os"

	"cuelabs.dev/go/oci/ociregistry/ocimem"
	"cuelabs.dev/go/oci/ociregistry/ociserver"
)

// x1b throwaway in-memory OCI registry; address from argv[1]. Every request
// is logged as "REQ <method> <path> <status> <bytes>" for request counting.
type rec struct {
	http.ResponseWriter
	code, n int
}

func (r *rec) WriteHeader(c int) { r.code = c; r.ResponseWriter.WriteHeader(c) }
func (r *rec) Write(b []byte) (int, error) {
	n, err := r.ResponseWriter.Write(b)
	r.n += n
	return n, err
}

func main() {
	h := ociserver.New(ocimem.New(), nil)
	log.Fatal(http.ListenAndServe(os.Args[1], http.HandlerFunc(func(w http.ResponseWriter, q *http.Request) {
		r := &rec{ResponseWriter: w, code: 200}
		h.ServeHTTP(r, q)
		fmt.Fprintf(os.Stdout, "REQ %s %s %d %d\n", q.Method, q.URL.RequestURI(), r.code, r.n)
	})))
}
