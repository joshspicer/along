FROM postgres:18-alpine
RUN apk add --no-cache age rclone tzdata && \
    addgroup -g 65532 -S backup && \
    adduser -u 65532 -S -D -H -G backup backup
COPY --chown=65532:65532 backup.sh restore.sh /usr/local/bin/
RUN chmod 0555 /usr/local/bin/backup.sh /usr/local/bin/restore.sh
USER 65532:65532
ENTRYPOINT ["/usr/local/bin/backup.sh"]
