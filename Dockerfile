ARG GOCD_VERSION=v20.5.0

# Docker compose
FROM docker/compose:1.26.0 AS compose

# Amazon ECR credential-helper
FROM golang:alpine3.12 AS ecr-credentials
RUN apk --no-cache add git=~2.26 && \
    go get -u github.com/awslabs/amazon-ecr-credential-helper/ecr-login/cli/docker-credential-ecr-login

# Helm and kubectl
FROM alpine:3.12 AS build
RUN apk add --update --no-cache curl

RUN curl -o /tmp/helm.tar.gz https://get.helm.sh/helm-v3.2.4-linux-amd64.tar.gz && \
    tar -C /tmp -zxvf /tmp/helm.tar.gz && \
    mv /tmp/linux-amd64/helm /usr/local/bin/helm

RUN curl -o /tmp/kubectl https://storage.googleapis.com/kubernetes-release/release/v1.18.4/bin/linux/amd64/kubectl && \
    chmod +x /tmp/kubectl && \
    mv /tmp/kubectl /usr/local/bin/kubectl

# GOCD image
FROM gocd/gocd-agent-docker-dind:"${GOCD_VERSION}"
USER root

#Install tools
RUN apk add --update --no-cache \
    jq=~1.6 \
    gnupg=~2.2 \
    make=~4.3

COPY --from=compose --chown=go:root /usr/local/bin/docker-compose /usr/local/bin/docker-compose
COPY --from=build --chown=go:root /usr/local/bin/helm /usr/local/bin/helm
COPY --from=build --chown=go:root /usr/local/bin/kubectl /usr/local/bin/kubectl
COPY --from=ecr-credentials --chown=go:root /go/bin/docker-credential-ecr-login /usr/local/bin/docker-credential-ecr-login

USER go
