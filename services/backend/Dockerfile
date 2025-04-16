# Stage 1: Build the binary in a Go environment
FROM golang:1.24 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
# Cross-compile for Linux; CGO_ENABLED=0 makes it fully static
RUN CGO_ENABLED=0 GOOS=linux go build -o backend .

# Stage 2: Create the final image with a minimal runtime
FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/backend .
RUN chmod +x backend
EXPOSE 8070
CMD ["./backend"]