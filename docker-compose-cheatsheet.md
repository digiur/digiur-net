## 🚀 Docker Compose Cheatsheet

Use these in the directory (or with `-f/--project-directory`) of any `docker-compose.yml`.

| Command                               | What it does                                        |
| ------------------------------------- | --------------------------------------------------- |
| `docker compose up -d`                | Create & start all services in background           |
| `docker compose down`                 | Stop & remove containers, networks (preserves data) |
| `docker compose down --volumes`       | …and also remove named volumes                      |
| `docker compose stop`                 | Stop running services (containers stay around)      |
| `docker compose start`                | Start stopped services                              |
| `docker compose restart [SERVICE]`    | Restart all (or one) service                        |
| `docker compose ps`                   | List services & their state                         |
| `docker compose logs -f [SERVICE]`    | Stream logs (all or specific service)               |
| `docker compose build [SERVICE]`      | (Re)build images                                    |
| `docker compose pull [SERVICE]`       | Pull latest images from registry                    |
| `docker compose exec [SERVICE] <cmd>` | Run a shell/command inside a live container         |

---

## 🐋 Core Docker commands

Good for “one-off” containers or inspecting under the hood.

| Command                            | What it does                           |
| ---------------------------------- | -------------------------------------- |
| `docker ps` / `docker ps -a`       | List running (or all) containers       |
| `docker stop <CONTAINER>`          | Gracefully stop a container            |
| `docker start <CONTAINER>`         | Start a stopped container              |
| `docker restart <CONTAINER>`       | Stop & immediately start               |
| `docker rm <CONTAINER>`            | Remove a stopped container             |
| `docker container prune`           | Remove all stopped containers          |
| `docker logs -f <CONTAINER>`       | Follow container logs                  |
| `docker exec -it <CONTAINER> bash` | Drop into a shell inside the container |
| `docker inspect <CONTAINER>`       | Show low-level config & metadata       |
| `docker stats [CONTAINER]`         | Live resource (CPU/memory/i/o) metrics |

---

## 🖼 Images, Volumes & Networks

| Command                | What it does                                      |
| ---------------------- | ------------------------------------------------- |
| `docker images`        | List local images                                 |
| `docker rmi <IMAGE>`   | Remove an image by ID or name                     |
| `docker image prune`   | Remove dangling images                            |
| `docker system prune`  | Remove unused data (containers, images, networks) |
| `docker volume ls`     | List volumes                                      |
| `docker volume prune`  | Remove all dangling volumes                       |
| `docker network ls`    | List networks                                     |
| `docker network prune` | Remove all unused networks                        |

---

## 🔧 Handy tips

* **One-liner rebuild & restart**

  ```bash
  docker compose pull \
    && docker compose up -d --build --force-recreate
  ```

  Grabs new images, rebuilds, and redeploys cleanly.

* **Troubleshoot a broken stack**

  ```bash
  docker compose down --volumes \
    && docker compose up -d
  ```

  Clears volumes (data!) and rebuilds from scratch.

* **Run a quick one-off**

  ```bash
  docker run --rm -it ubuntu:latest bash
  ```

  Spins up an ephemeral Ubuntu shell.

* **Clean up everything (be cautious!)**

  ```bash
  docker system prune -a --volumes
  ```

  Removes all stopped containers, unused images (even tagged), and volumes.

---
