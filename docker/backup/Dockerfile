# Daily copy of PostgreSQL to an S3-compatible bucket (the Lightsail object storage): pg_dumpall of the same major
# version as the server and the AWS CLI
FROM postgres:17-alpine
RUN apk add --no-cache aws-cli
COPY backup.sh /usr/local/bin/backup.sh
USER postgres
ENTRYPOINT ["/usr/local/bin/backup.sh"]
