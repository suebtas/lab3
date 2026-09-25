# syntax=docker/dockerfile:1

# =============================================================================
# startup_hr - immutable static web deployment
# Multi-stage: quality -> builder -> runtime (unprivileged Nginx)
# Build context = repository root. See deploy/CICD/Dockerfile.dockerignore.
# =============================================================================

# Flutter builder: Flutter 3.44.0 / Dart 3.12.0, pinned by digest
# (verified 2026-09-25 via `flutter --version` inside this image).
ARG FLUTTER_IMAGE=ghcr.io/cirruslabs/flutter
ARG FLUTTER_TAG=stable
ARG FLUTTER_DIGEST=sha256:46691e311715845de03a3ba4753a475476936805b29431b1f00f1816981033f8

# Runtime: Nginx 1.27.5 unprivileged, pinned by digest
# (nginxinc/nginx-unprivileged:1.27-alpine; runs as nginx uid 101, port 8080).
ARG NGINX_IMAGE=nginxinc/nginx-unprivileged
ARG NGINX_TAG=1.27-alpine
ARG NGINX_DIGEST=sha256:65e3e85dbaed8ba248841d9d58a899b6197106c23cb0ff1a132b7bfe0547e4c0

# ---------------------------------------------------------------------------
# base: application source + dependency restore
# ---------------------------------------------------------------------------
FROM ${FLUTTER_IMAGE}:${FLUTTER_TAG}@${FLUTTER_DIGEST} AS base

WORKDIR /app

COPY pubspec.yaml pubspec.lock analysis_options.yaml ./
COPY lib lib
COPY test test
COPY web web
COPY assets assets

RUN flutter pub get

# ---------------------------------------------------------------------------
# quality: quality gates (fails the build when analyze or tests fail)
# ---------------------------------------------------------------------------
FROM base AS quality

RUN flutter analyze \
    && flutter test

# ---------------------------------------------------------------------------
# builder: release Web build
# builder depends on quality, so `--target runtime` can never skip the
# quality gates - analyze and test always run before the Web build.
# ---------------------------------------------------------------------------
FROM quality AS builder

RUN flutter build web --release

# ---------------------------------------------------------------------------
# runtime: portable immutable image, no source, no Flutter SDK, no build tools
# ---------------------------------------------------------------------------
FROM ${NGINX_IMAGE}:${NGINX_TAG}@${NGINX_DIGEST} AS runtime

# OCI image labels are build arguments (defaults for local builds; CI overrides
# them with the Git commit SHA and repository URL).
ARG LABEL_SOURCE="https://github.com/suebtas/lab3"
ARG LABEL_VERSION="1.0.0"
ARG LABEL_REVISION="unknown"
ARG LABEL_CREATED="unknown"

LABEL org.opencontainers.image.title="startup_hr"
LABEL org.opencontainers.image.description="Startup HR Flutter Web, served by unprivileged Nginx"
LABEL org.opencontainers.image.source="${LABEL_SOURCE}"
LABEL org.opencontainers.image.ref.name="startup-hr:local"
LABEL org.opencontainers.image.version="${LABEL_VERSION}"
LABEL org.opencontainers.image.revision="${LABEL_REVISION}"
LABEL org.opencontainers.image.created="${LABEL_CREATED}"

USER root

COPY --from=builder /app/build/web /usr/share/nginx/html
COPY deploy/CICD/nginx.conf /etc/nginx/nginx.conf

RUN rm -f /etc/nginx/conf.d/default.conf \
    && chown -R nginx:nginx /usr/share/nginx/html

USER nginx

EXPOSE 8080

STOPSIGNAL SIGQUIT

HEALTHCHECK --interval=5s --timeout=3s --start-period=10s --retries=12 \
    CMD ["wget", "-q", "-O", "/dev/null", "http://127.0.0.1:8080/healthz"]