# syntax=docker/dockerfile:1.12

FROM golang:1.26.5-alpine AS build
ARG TARGETOS=linux
ARG TARGETARCH
WORKDIR /src
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -trimpath -ldflags="-s -w" -o /out/alongd ./cmd/alongd && \
    CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -trimpath -ldflags="-s -w" -o /out/migrate ./cmd/migrate && \
    CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -trimpath -ldflags="-s -w" -o /out/apns-worker ./cmd/apns-worker

FROM alpine:3.22
ARG GIT_COMMIT=unknown
ENV GIT_COMMIT=${GIT_COMMIT}
RUN apk add --no-cache ca-certificates tzdata && \
    addgroup -g 65532 -S along && \
    adduser -u 65532 -S -D -H -G along along
WORKDIR /app
COPY --from=build --chown=65532:65532 /out/alongd /out/migrate /out/apns-worker /app/
USER 65532:65532
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD ["wget", "-q", "-O", "-", "http://127.0.0.1:8080/health/live"]
ENTRYPOINT ["/app/alongd"]

