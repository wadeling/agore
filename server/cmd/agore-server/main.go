package main

import (
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/wadeling/agore/server/internal/hub"
)

func main() {
	token := strings.TrimSpace(os.Getenv("AGORE_TOKEN"))
	if token == "" {
		log.Fatal("AGORE_TOKEN is required")
	}
	addr := os.Getenv("AGORE_ADDR")
	if addr == "" {
		addr = ":8081"
	}

	h := hub.New(token)
	mux := http.NewServeMux()
	mux.Handle("/v1/plaza", h)
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	log.Printf("agore plaza listening on %s", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatal(err)
	}
}
