package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/golang-jwt/jwt"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"

	core "github.com/envoyproxy/go-control-plane/envoy/config/core/v3"
	extauth "github.com/envoyproxy/go-control-plane/envoy/service/auth/v3"
	rpcstatus "google.golang.org/genproto/googleapis/rpc/status"
)

var jwtSecret = []byte("secret")

type Credentials struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

func healthcheckHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("ok"))
}

func loginHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("=== Received login request ===")
	if r.Method != http.MethodPost {
		http.Error(w, "Only POST method is allowed", http.StatusMethodNotAllowed)
		return
	}

	var creds Credentials
	if err := json.NewDecoder(r.Body).Decode(&creds); err != nil {
		http.Error(w, "Invalid request payload", http.StatusBadRequest)
		return
	}

	if creds.Username != "user" || creds.Password != "password" {
		http.Error(w, "Invalid credentials", http.StatusUnauthorized)
		return
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"username": creds.Username,
		"exp":      time.Now().Add(time.Hour).Unix(),
	})
	tokenString, err := token.SignedString(jwtSecret)
	if err != nil {
		http.Error(w, "Error generating token", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"token": tokenString})
}

type extAuthServer struct {
	extauth.UnimplementedAuthorizationServer
}

func (s *extAuthServer) Check(ctx context.Context, req *extauth.CheckRequest) (*extauth.CheckResponse, error) {
	log.Println("=== Received ext_authz Check request ===")
	log.Printf("Request headers: %v\n", req.Attributes.Request.Http.Headers)

	var token string
	for key, val := range req.Attributes.Request.Http.Headers {
		if strings.ToLower(key) == "authorization" {
			token = val
			break
		}
	}
	log.Printf("Extracted Authorization header: %q\n", token)

	if token == "" {
		log.Println("Missing Authorization token")
		return &extauth.CheckResponse{
			Status: &rpcstatus.Status{
				Code:    int32(7),
				Message: "Missing token",
			},
		}, nil
	}

	parts := strings.Split(token, " ")
	if len(parts) != 2 {
		log.Println("Invalid Authorization header format")
		return &extauth.CheckResponse{
			Status: &rpcstatus.Status{
				Code:    int32(7),
				Message: "Invalid token format",
			},
		}, nil
	}
	tokenStr := parts[1]
	log.Printf("JWT Token: %s\n", tokenStr)

	parsedToken, err := jwt.Parse(tokenStr, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			log.Printf("Unexpected signing method: %v\n", token.Header["alg"])
			return nil, fmt.Errorf("unexpected signing method")
		}
		return jwtSecret, nil
	})
	if err != nil || !parsedToken.Valid {
		log.Printf("Invalid JWT: %v\n", err)
		return &extauth.CheckResponse{
			Status: &rpcstatus.Status{
				Code:    int32(7),
				Message: "Invalid token",
			},
		}, nil
	}

	log.Println("JWT is valid. Authorizing request...")

	return &extauth.CheckResponse{
		Status: &rpcstatus.Status{
			Code:    int32(0),
			Message: "OK",
		},
		HttpResponse: &extauth.CheckResponse_OkResponse{
			OkResponse: &extauth.OkHttpResponse{
				Headers: []*core.HeaderValueOption{
					{
						Header: &core.HeaderValue{
							Key:   "x-authenticated-user",
							Value: "user",
						},
					},
				},
			},
		},
	}, nil
}

func startHTTP(port string) {
	http.HandleFunc("/healthcheck", healthcheckHandler)
	http.HandleFunc("/login", loginHandler)
	log.Printf("Auth HTTP server listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func startGRPC(grpcPort string) {
	lis, err := net.Listen("tcp", ":"+grpcPort)
	if err != nil {
		log.Fatalf("Failed to listen on :%s: %v", grpcPort, err)
	}
	grpcServer := grpc.NewServer()
	extauth.RegisterAuthorizationServer(grpcServer, &extAuthServer{})
	reflection.Register(grpcServer)
	log.Printf("Auth GRPC ext_authz server listening on :%s", grpcPort)
	if err := grpcServer.Serve(lis); err != nil {
		log.Fatalf("Failed to serve GRPC server: %v", err)
	}
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	grpcPort := os.Getenv("GRPC_PORT")
	if grpcPort == "" {
		grpcPort = "9191"
	}

	// Run both servers concurrently.
	go startGRPC(grpcPort)
	startHTTP(port)
}
