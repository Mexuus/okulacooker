# syntax=docker/dockerfile:1
#
# OkulaCooker web app: build with Flutter, serve with unprivileged nginx.
#   docker build -t okulacooker .
#   docker run -d -p 8080:8080 okulacooker
#
# The build stage runs on the builder's native platform (the output is plain
# static files), so multi-arch images (amd64 + arm64) build quickly.

ARG FLUTTER_VERSION=3.47.7

FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS build
ARG FLUTTER_VERSION
RUN apt-get update \
 && apt-get install -y --no-install-recommends git curl unzip xz-utils ca-certificates \
 && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch "${FLUTTER_VERSION}" https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"
RUN flutter config --no-analytics --enable-web \
 && flutter precache --web

WORKDIR /app
# Dependencies first so they're cached between code changes.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
# Serve from a sub-path (e.g. behind a reverse proxy) with --build-arg BASE_HREF=/okulacooker/
ARG BASE_HREF=/
RUN flutter build web --release --no-wasm-dry-run --base-href "${BASE_HREF}"

FROM nginxinc/nginx-unprivileged:1.28-alpine
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --chmod=755 docker/40-okulacooker-config.sh /docker-entrypoint.d/40-okulacooker-config.sh
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1
