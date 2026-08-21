FROM listmonk/listmonk:v6.2.0

# curl is not in the upstream image; used for HEALTHCHECK.
RUN apk --no-cache add curl

COPY listmonk-start.sh /usr/local/bin/listmonk-start.sh
RUN chmod +x /usr/local/bin/listmonk-start.sh

CMD ["/usr/local/bin/listmonk-start.sh"]

HEALTHCHECK --interval=5s --timeout=3s --start-period=25s --retries=12 \
	CMD curl -fsS http://127.0.0.1:9000/api/health || exit 1
