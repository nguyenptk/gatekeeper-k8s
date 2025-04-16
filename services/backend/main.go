package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func healthcheckHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("ok"))
}

func publicHandler(w http.ResponseWriter, r *http.Request) {
	appName := os.Getenv("APP_NAME")
	if appName == "" {
		appName = "my-gatekeeper-k8s"
	}
	w.Header().Set("Content-Type", "text/plain")
	fmt.Fprint(w, appName)
}

func privateHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain")
	fmt.Fprint(w, "Welcome to my private property!")
}

func main() {
	http.HandleFunc("/healthcheck", healthcheckHandler)
	http.HandleFunc("/public", publicHandler)
	http.HandleFunc("/private", privateHandler)
	port := os.Getenv("PORT")
	if port == "" {
		port = "8070"
	}
	log.Printf("Backend server starting on port %s...", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
