# Developer Documentation

This document explains how to set up, build, run and maintain the Inception
project from a developer's point of view.

## Set up the environment from scratch

### Prerequisites

- A Linux host or virtual machine (the project was developed on Ubuntu).
- Docker Engine and Docker Compose installed.
- The current user added to the `docker` group, so Docker runs without `sudo`:

  ```bash
  sudo usermod -aG docker $USER
  newgrp docker      # apply the group in the current shell
  docker ps          # should work without sudo
  ```

- The domain mapped to the local machine in `/etc/hosts`:

  ```
  127.0.0.1   lgertrud.42.fr
  ```

- The data folder must exist and belong to the current user. Docker will not
  create the bind source folder on its own, and `/home` is not writable by a
  normal user, so create it once per machine:

  ```bash
  sudo mkdir -p /home/lgertrud
  sudo chown -R $USER:$USER /home/lgertrud
  ```

### Configuration files

- `srcs/.env` holds the non-sensitive configuration. It must sit next to
  `docker-compose.yml`, because Compose reads the `.env` from the compose
  directory. It defines the domain, the database name, the WordPress usernames,
  emails and title. Example:

  ```
  DOMAIN_NAME=lgertrud.42.fr
  MYSQL_DATABASE=wordpress
  MYSQL_USER=lger
  WP_TITLE=Inception
  WP_ADMIN_USER=boss
  WP_ADMIN_EMAIL=boss@example.com
  WP_USER=visitant
  WP_USER_EMAIL=visitant@example.com
  ```

### Secrets

Passwords are not stored in the `.env` or in any Dockerfile. They live in the
`secrets/` folder at the repository root, one password per file:
`db_root_password.txt`, `db_password.txt`, `wp_admin_password.txt` and
`wp_user_password.txt`. They can be generated locally, for example:

```bash
openssl rand -hex 20 > secrets/db_password.txt
```

Docker Compose mounts each secret inside the containers at `/run/secrets/<name>`
only at runtime, and the entrypoint scripts read them from there. Both
`srcs/.env` and `secrets/` are listed in `.gitignore` and must never be
committed.

## Build and launch the project

Everything is driven by the `Makefile` at the repository root, which calls
Docker Compose with `srcs/docker-compose.yml`.

```bash
make        # create the host data folders, build the images, start the stack
make build  # build the images without starting the containers
make down   # stop and remove the containers (data preserved)
make re     # full reset: wipe data and rebuild from scratch
make logs   # follow the logs of all services
```

The default target runs `mkdir -p` for the two data folders and then
`docker compose up -d --build`. The `-d` runs detached, and `--build` forces the
images to be rebuilt, which satisfies the requirement that the Makefile builds
the images through Docker Compose.

Each service is built from `debian:bookworm` and defined under
`srcs/requirements/<service>/`, with its `Dockerfile`, its `conf/` and, when it
needs runtime setup, an entrypoint in `tools/`. NGINX receives the domain as a
build argument, passed from the `.env` through Compose to the `ARG` in its
Dockerfile.

## Manage containers and volumes

Useful commands during development:

- **List containers and status:** `docker ps` (add `-a` to see stopped ones).
- **Open a shell inside a container:**

  ```bash
  docker exec -it mariadb bash
  ```

- **Read one service's logs:** `docker logs wordpress`.
- **List volumes and networks:**

  ```bash
  docker volume ls
  docker network ls
  ```

The Makefile targets form a scale from the lightest to the most destructive:

- `stop` / `start` freeze and resume the containers, changing nothing else.
- `down` removes the containers and the network, keeping the volumes and the
  host data.
- `clean` runs `down -v`, which also removes the Docker volume objects, but the
  host data under `/home/lgertrud/data` still remains (see persistence below).
- `fclean` runs `clean`, then deletes the host data folder with `sudo` and prunes
  unused images and cache. This is the only target that truly erases the data.
- `re` runs `fclean` then `make`, for a completely fresh rebuild.

## Where data is stored and how it persists

The two named volumes are declared in `docker-compose.yml` with `driver_opts`
that bind them to host folders:

- `mariadb_data` is mounted at `/var/lib/mysql` in the database container and
  stored at `/home/lgertrud/data/mariadb`.
- `wordpress_data` is mounted at `/var/www/html` and stored at
  `/home/lgertrud/data/wordpress`. This same volume is also mounted in the NGINX
  container, so NGINX serves the exact files that WordPress installs.

This design keeps the data in two layers. The first layer is the Docker volume
object, referenced by name in the compose file. The second layer is the physical
folder on the host, which exists independently of Docker. Because of this
separation, `make down` and even `make clean` (`down -v`) preserve the data: they
remove containers and volume objects, but not the host folder. The entrypoint
scripts detect existing data on start (MariaDB checks whether its system tables
exist, WordPress checks whether `wp-config.php` exists) and skip
reinitialization, so the site returns unchanged after `make down && make`. Only
`make fclean`, which deletes `/home/lgertrud/data`, produces a genuine first
boot on the next `make`.

The files inside `/home/lgertrud/data` are written by the container users
(`mysql` and `www-data`), so removing them from the host requires `sudo`, which
is why `fclean` uses it.
