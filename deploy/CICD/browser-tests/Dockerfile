# syntax=docker/dockerfile:1

# Browser smoke-test runner for startup_hr.
# Build context = repository root. This Dockerfile has its own trailing
# Dockerfile.dockerignore (BuildKit honors the ignore file that sits next to
# the Dockerfile being built), so only the harness source reaches the builder.
# The Playwright base image already bundles the pinned browsers; only the
# harness deps are installed here.
ARG PW_IMAGE=mcr.microsoft.com/playwright
ARG PW_TAG=v1.49.0-jammy
ARG PW_DIGEST=sha256:98b1ad488de36b22d41fdd1b0c5b9cceaa78a8d2661c6ab02d2108a07c182338

FROM ${PW_IMAGE}:${PW_TAG}@${PW_DIGEST}

WORKDIR /app

COPY deploy/CICD/browser-tests/package.json deploy/CICD/browser-tests/package-lock.json ./
RUN npm ci --no-audit --no-fund

COPY deploy/CICD/browser-tests/ ./

ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

CMD ["npx", "playwright", "test", "--reporter=list"]