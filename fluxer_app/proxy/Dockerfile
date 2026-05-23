FROM golang:1.25.5-alpine AS build

WORKDIR /build

COPY fluxer_app/proxy/go.mod ./
COPY fluxer_app/proxy/go.sum* ./
RUN go mod download

COPY fluxer_app/proxy/ .

COPY fluxer_app/dist/ assets/
RUN set -eu; \
  for ref in $(grep -o '"/assets/[^"]*"' assets/index.html | tr -d '"' | sed 's#^/##' | sort -u); do \
    test -f "assets/${ref}" || { echo "missing app asset: ${ref}" >&2; exit 1; }; \
  done

ARG TARGETOS=linux
ARG TARGETARCH=amd64
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -o fluxer-app-proxy

FROM alpine:3.19

RUN apk add --no-cache ca-certificates curl

WORKDIR /app

COPY --from=build /build/fluxer-app-proxy /app/fluxer-app-proxy

USER nobody

EXPOSE 8080
ENV PORT=8080

ENTRYPOINT ["/app/fluxer-app-proxy"]
