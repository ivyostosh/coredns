FROM public.ecr.aws/bitnami/golang:1.20.1 AS binaryBuilder
WORKDIR /go/src/github.com/coredns/coredns

# Configure build with Go modules
ENV GO111MODULE=on
ENV GOPROXY=direct

# Copy modules in before the rest of the source to only expire cache on module changes
COPY go.mod go.sum ./
RUN go mod download

COPY .git/ .git/
COPY coredns.go directives_generate.go Makefile owners_generate.go plugin.cfg ./
COPY core/ core/
COPY coremain/ coremain/
COPY pb/ pb/
COPY plugin/ plugin/
COPY request/ request/
RUN make coredns

FROM --platform=$BUILDPLATFORM debian:stable-slim AS build
SHELL [ "/bin/sh", "-ec" ]

RUN export DEBCONF_NONINTERACTIVE_SEEN=true \
           DEBIAN_FRONTEND=noninteractive \
           DEBIAN_PRIORITY=critical \
           TERM=linux ; \
    apt-get -qq update ; \
    apt-get -yyqq upgrade ; \
    apt-get -yyqq install ca-certificates libcap2-bin; \
    apt-get clean
COPY --from=binaryBuilder /go/src/github.com/coredns/coredns/coredns /coredns
RUN setcap cap_net_bind_service=+ep /coredns

FROM --platform=$TARGETPLATFORM gcr.io/distroless/static-debian11:nonroot
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /coredns /coredns
USER nonroot:nonroot
EXPOSE 53 53/udp
ENTRYPOINT ["/coredns"]
