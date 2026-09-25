# OpenCode container with Docker access

`docker-compose.override.yml` extends the existing `opencode-env` service without modifying the root `docker-compose.yml`.

The custom image adds the Linux Docker CLI, Buildx, and Docker Compose plugin. The override mounts Docker Desktop's Linux Engine socket at `/var/run/docker.sock`, allowing OpenCode to create sibling containers through the host Docker Engine.

This socket grants broad control over Docker containers, images, networks, volumes, and bind mounts. Use this environment only with trusted code and prompts. It must not contain registry credentials, SSH private keys, or production secrets.

From Windows PowerShell, rebuild and start the environment with:

```powershell
docker compose build opencode-env
docker compose up -d opencode-env
docker compose exec opencode-env sh
```

Inside the container, verify access before running deployment work:

```sh
docker version
docker compose version
```

`docker version` must report both Client and Server. If the socket mount is blocked by Docker Desktop Enhanced Container Isolation, do not expose the daemon over unauthenticated TCP; configure a trusted-image socket exception or run Docker commands from the Windows host instead.
