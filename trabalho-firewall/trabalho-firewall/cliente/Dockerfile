FROM alpine:3.20
RUN apk add --no-cache curl nmap iproute2 netcat-openbsd
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
