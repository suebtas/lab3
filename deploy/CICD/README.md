# startup_hr - Local Docker deployment

Immutable static Flutter Web deployment for `startup_hr` using a multi-stage
Dockerfile (`quality` -> `builder` -> `runtime`). The runtime image is a
portable Nginx image that can be tested, saved and promoted without rebuild.

## Toolchain (pinned)

- Builder: `ghcr.io/cirruslabs/flutter:stable@sha256:46691e31...f8` (Flutter 3.44.0 / Dart 3.12.0)
- Runtime: `nginxinc/nginx-unprivileged:1.27-alpine@sha256:65e3e85d...e4c0` (Nginx 1.27.5)
- Images are referenced by digest; no `latest` for runtime base images.

## Requirements

- Docker Engine with Docker Compose v2 (Compose v2.20+ recommended)
- BuildKit (default in modern Docker)

## Prepare

```bash
cp deploy/CICD/.env.example deploy/CICD/.env
# edit APP_PORT if 8080 collides with another service on this host
```

`.env` is git-ignored and intentionally contains no secrets.

## Validate configuration

```bash
docker compose --project-name lab3-cicd --env-file deploy/CICD/.env \
  -f deploy/CICD/docker-compose.yml config
```

## Build targets

Quality gates (fails when `flutter analyze` or `flutter test` fails):

```bash
docker build -f deploy/CICD/Dockerfile --target quality -t startup-hr:quality .
```

Portable runtime image (the `builder` stage extends `quality`, so `--target
runtime` always runs `flutter analyze` and `flutter test` before the Web build
- the quality gates cannot be skipped):

```bash
docker build -f deploy/CICD/Dockerfile --target runtime -t startup-hr:local .
```

OCI labels (`source`, `version`, `revision`, `created`) are build arguments.
Local builds default to `unknown` revision; CI passes the Git commit SHA:

```bash
docker build -f deploy/CICD/Dockerfile --target runtime -t startup-hr:local \
  --build-arg LABEL_SOURCE="https://github.com/suebtas/lab3" \
  --build-arg LABEL_VERSION="1.0.0" \
  --build-arg LABEL_REVISION="<full-commit-sha>" \
  --build-arg LABEL_CREATED="$(date -u +%Y-%m-%dT%H:%M:%SZ)" .
```

Or build the runtime image through Compose (`LABEL_*` env vars are optional):

```bash
docker compose --project-name lab3-cicd --env-file deploy/CICD/.env \
  -f deploy/CICD/docker-compose.yml build
```

## Start

```bash
docker compose --project-name lab3-cicd --env-file deploy/CICD/.env \
  -f deploy/CICD/docker-compose.yml up -d
```

## Verify

```bash
docker compose --project-name lab3-cicd --env-file deploy/CICD/.env \
  -f deploy/CICD/docker-compose.yml ps
docker compose --project-name lab3-cicd --env-file deploy/CICD/.env \
  -f deploy/CICD/docker-compose.yml logs --no-color
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/healthz
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/
```

Open the app: http://localhost:8080

## Stop and remove this project's resources

```bash
docker compose --project-name lab3-cicd --env-file deploy/CICD/.env \
  -f deploy/CICD/docker-compose.yml down --remove-orphans
```

## Automated browser validation (Playwright)

The runtime image is opened in a real browser inside a dedicated `browser-test`
service on the same Compose network. The test drives the app at the in-network
URL `http://startup-hr-web:8080` (never `localhost`) and asserts that the
Flutter engine boots, renders and produces no console errors, page errors or
failed network requests (screenshots, video and traces are emitted by the
runner).

The `browser-test` image is built from `deploy/CICD/browser-tests/Dockerfile`
(the command below auto-builds it), so the harness is not part of the runtime
image:

```bash
docker compose --project-name lab3-cicd --env-file deploy/CICD/.env \
  -f deploy/CICD/docker-compose.yml -f deploy/CICD/docker-compose.test.yml \
  run --rm browser-test
```

## Self-contained runtime (no external fetch)

The strict CSP on the runtime Nginx allows only same-origin resources, so the
Flutter bootstrapper is overridden by `web/flutter_bootstrap.js` to load
CanvasKit from the locally-shipped `canvaskit/` directory and the Roboto /
Noto Sans Thai fonts are bundled as app assets (see `pubspec.yaml`). The
container does not contact `gstatic.com` or any CDN.

## Production (image promotion, no push)

```bash
export IMAGE_REF=ghcr.io/suebtas/lab3@sha256:<published-digest>
docker compose --env-file deploy/CICD/.env \
  -f deploy/CICD/docker-compose.production.yml config
```

The production compose references a published image only - no `build:` and no
source/build mounts.

## Offline transfer of the portable image

```bash
docker save startup-hr:local | gzip > startup-hr-local.tar.gz
sha256sum startup-hr-local.tar.gz
# on the target machine:
docker load < startup-hr-local.tar.gz
```

## Notes

- Never exposes `lib/`, `test/`, `web/` or `build/web` from the host to the
  container; static assets are baked into the image.
- The runtime container runs as the `nginx` user with a read-only rootfs,
  all capabilities dropped and only `/tmp`, `/var/cache/nginx` and
  `/var/run` mounted as tmpfs.
- Nginx cache policy: `index.html`, the bootstrappers (`flutter.js`,
  `flutter_bootstrap.js`, `flutter_service_worker.js`, `main.dart.js`) and
  manifests are never cached as immutable (they are the update/revalidation
  entry points); long-term `immutable` caching is reserved for content-hashed
  filenames; other static assets get a bounded revalidatable cache.