FROM golang:1.26.5-alpine AS tools
WORKDIR /build
RUN go mod init along.backup/tools && \
    go get filippo.io/age/cmd/age@v1.3.1 && \
    go get golang.org/x/crypto@latest golang.org/x/sys@latest golang.org/x/term@latest && \
    CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/age filippo.io/age/cmd/age

FROM alpine:3.23
RUN apk add --no-cache curl postgresql18-client tzdata && \
    addgroup -g 65532 -S backup && \
    adduser -u 65532 -S -D -H -G backup backup
COPY --from=tools /out/age /usr/local/bin/age
COPY --chown=65532:65532 backup.sh restore.sh /usr/local/bin/
RUN chmod 0555 /usr/local/bin/age /usr/local/bin/backup.sh /usr/local/bin/restore.sh
USER 65532:65532
ENTRYPOINT ["/usr/local/bin/backup.sh"]
