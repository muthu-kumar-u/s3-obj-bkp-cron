FROM restic/restic:0.19.1
RUN apk add --no-cache util-linux
COPY scripts/backup.sh /usr/local/bin/backup.sh
ENTRYPOINT ["sh", "/usr/local/bin/backup.sh"]
