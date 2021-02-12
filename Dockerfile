ARG GOCD_VERSION=v20.6.0

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

# AWS CLI
FROM alpine:3.12 AS awscli
ENV GLIBC_VER=2.31-r0
RUN apk --no-cache add \
    binutils \
    curl \
    && curl -sL https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub -o /etc/apk/keys/sgerrand.rsa.pub \
    && curl -sLO https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VER}/glibc-${GLIBC_VER}.apk \
    && curl -sLO https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VER}/glibc-bin-${GLIBC_VER}.apk \
    && apk add --no-cache \
        glibc-${GLIBC_VER}.apk \
        glibc-bin-${GLIBC_VER}.apk

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install --bin-dir /aws-cli-bin/

# GOCD image
FROM gocd/gocd-agent-docker-dind:"${GOCD_VERSION}"
USER root

#Install tools
RUN apk add --update --no-cache \
    jq=~1.6 \
    gnupg=~2.2 \
    make=~4.3 \
    less \ 
    groff \
    libstdc++

COPY --from=compose --chown=go:root /usr/local/bin/docker-compose /usr/local/bin/docker-compose
COPY --from=build --chown=go:root /usr/local/bin/helm /usr/local/bin/helm
COPY --from=build --chown=go:root /usr/local/bin/kubectl /usr/local/bin/kubectl
COPY --from=awscli --chown=go:root /usr/local/aws-cli/ /usr/local/aws-cli/
COPY --from=awscli --chown=go:root /aws-cli-bin/ /usr/local/bin/
COPY --from=ecr-credentials --chown=go:root /go/bin/docker-credential-ecr-login /usr/local/bin/docker-credential-ecr-login

USER go
