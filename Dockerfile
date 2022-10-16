FROM docker.io/library/golang:alpine as builder

ARG BUILD_VERSION=0.1.0

# build server
WORKDIR /server
COPY . .
RUN set -ex \
	&& apk add --no-cache build-base \
	&& go mod download && go mod verify \
	&& PB_BUILD_VERSION="$BUILD_VERSION" make build \
	&& chmod +x /server/out/pushbits

# build cli
RUN apk add --no-cache git \
    && git clone https://github.com/nonedotone/pushbits-cli.git /cli \
    && cd /cli && go mod download && go mod verify \
    && PBCLI_BUILD_VERSION="$BUILD_VERSION" make build \
    && chmod +x /cli/out/pbcli


FROM docker.io/library/alpine

ARG USER_ID=1000

ENV PUSHBITS_HTTP_PORT="8080"

EXPOSE 8080

WORKDIR /app

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /server/out/pushbits /usr/bin/pushbits
COPY --from=builder /cli/out/pbcli /usr/bin/pbcli

RUN set -ex \
	&& apk add --no-cache ca-certificates curl \
	&& update-ca-certificates \
	&& mkdir -p /data \
	&& ln -s /data/pushbits.db /app/pushbits.db \
	&& ln -s /data/config.yml /app/config.yml \
    && chmod +x /usr/bin/pushbits && chmod +x /usr/bin/pushbits

USER ${USER_ID}

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s CMD curl --fail http://localhost:$PUSHBITS_HTTP_PORT/health || exit 1

ENTRYPOINT ["/usr/bin/pushbits"]
