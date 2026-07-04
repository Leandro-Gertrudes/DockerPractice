*This project has been created as part of the 42 curriculum by lgertrud.*

# Inception

## Description

Inception is a system-administration project that builds a small web
infrastructure entirely with Docker, running inside a virtual machine. It
brings up three services, each in its own container, built from custom
Dockerfiles, no ready-made images are pulled from Docker Hub (only the Debian
base image is used).

- **NGINX** — the single entry point, reachable only on port 443 over TLS 1.2/1.3.
- **WordPress + php-fpm** — the application that serves the site.
- **MariaDB** — the database that backs WordPress.

The containers talk to each other over a private Docker network, persist their
data in named volumes stored under `/home/lgertrud/data`, receive their
passwords through Docker secrets, and restart automatically on failure. The
whole stack is built and launched from a single `make` command.

The site is served at **https://lgertrud.42.fr**.

## Architecture

```
                          Host machine (VM)
   ┌───────────────────────────────────────────────────────────┐
   │                                                             │
   │   Browser ──443/TLS──▶  NGINX                               │
   │                           │                                 │
   │                     9000/FastCGI                            │
   │                           ▼                                 │
   │                     WordPress + php-fpm ──3306──▶ MariaDB    │
   │                           │                         │       │
   │                    wordpress_data              mariadb_data  │
   │                   (/var/www/html)             (/var/lib/mysql)
   │                                                             │
   │   Docker network: "inception" (bridge)                      │
   └───────────────────────────────────────────────────────────┘

   Only NGINX publishes a port to the host (443). MariaDB and WordPress are
   reachable only from inside the "inception" network. Both volumes are stored
   on the host under /home/lgertrud/data.
```

## Instructions

**Prerequisites:** a Linux host (or VM) with Docker Engine and Docker Compose,
the domain mapped in `/etc/hosts`, and the `.env` and `secrets/` files in place.
The full setup from scratch is documented in `DEV_DOC.md`.

From the repository root:

```bash
make        # build the images and start the whole stack (detached)
make down   # stop and remove the containers (data is preserved)
make logs   # follow the logs of all services
make re     # full reset: wipe data and rebuild from scratch
```

Then open **https://lgertrud.42.fr** in a browser and accept the self-signed
certificate warning. The administration panel is at
**https://lgertrud.42.fr/wp-admin**.

Everyday usage is described in `USER_DOC.md`; developer setup and maintenance
in `DEV_DOC.md`.

## Project description

### Use of Docker and project sources

Each service lives in its own directory under `srcs/requirements/<service>/`,
containing its `Dockerfile`, its configuration (`conf/`) and, when it needs
runtime setup, an entrypoint script (`tools/`). All images are built from
`debian:bookworm`, the penultimate stable Debian (Trixie is the current
stable), and never from the `latest` tag.

- **mariadb** — installs `mariadb-server`. Its entrypoint initializes the data
  directory on first boot, creates the database and the two users, and runs
  `mariadbd` in the foreground as PID 1.
- **wordpress** — installs php-fpm and WP-CLI. Its entrypoint waits for the
  database to be reachable, downloads and installs WordPress, creates the two
  users, and runs php-fpm in the foreground.
- **nginx** — installs nginx and generates a self-signed TLS certificate at
  build time. It serves the WordPress files and forwards PHP requests to
  `wordpress:9000`.

`srcs/docker-compose.yml` wires everything together: the private network, the
named volumes, the secrets and the restart policy. The `Makefile` prepares the
host data folders and calls Docker Compose to build and run the stack.

### Design choices

#### Virtual Machines vs Docker

A virtual machine emulates a full computer: it ships its own complete operating
system and kernel on top of a hypervisor, which makes it heavy to boot and store
but strongly isolated. A Docker container instead shares the host kernel and
packages only the application and its dependencies, which makes it lightweight,
fast to start and easy to reproduce. This project uses both on purpose: the VM
provides an isolated, disposable machine to work on, and Docker provides the
per-service isolation inside it. Three containers on one small VM would be far
cheaper than three separate virtual machines.

#### Secrets vs Environment Variables

Environment variables (kept in `srcs/.env`) hold non-sensitive configuration:
the domain name, the database name, the usernames, the site title. They are
convenient and readable, but anything placed in them can leak, through
`docker inspect`, through image layers, or through the process environment, so
they are the wrong place for passwords. Docker secrets are used for every
password instead: each secret is a file that Docker mounts inside the container
at `/run/secrets/<name>` only while it runs, is never written into an image
layer, and is kept out of Git. In short, `.env` for configuration, secrets for
credentials.

#### Docker Network vs Host Network

With the host network, containers share the host's network stack directly and
have no isolation between them or from the host. This project uses a dedicated
bridge network called `inception` instead. It isolates the three containers from
the host's network, exposes only what is explicitly published (port 443 on
NGINX), and gives built-in service discovery: each container can reach another
by its name (WordPress connects to `mariadb`, NGINX forwards to `wordpress:9000`)
because Docker resolves those names to the right container. The subject forbids
`network: host`, `--link` and `links:` for exactly these isolation reasons.

#### Docker Volumes vs Bind Mounts

A bind mount maps a specific host path straight into a container; it is simple
but ties the container to the host's filesystem layout and is managed entirely
by the user. A named volume is a first-class Docker object, referenced by name,
that Docker manages. The subject requires named volumes but also requires the
data to live under `/home/lgertrud/data`, so this project declares named volumes
whose `driver_opts` bind them to that host path. The result is a named volume in
form (declared and referenced by name, `mariadb_data` and `wordpress_data`)
whose bytes physically live in `/home/lgertrud/data`. A practical consequence is
that removing the Docker volume object (`docker compose down -v`) does not delete
the data, because the underlying host folder exists independently, only
`make fclean`, which deletes that folder, truly wipes the data.

## Resources

Classic references used while working on this project:

- Docker documentation — Dockerfile best practices, the Compose file reference,
  secrets, named volumes and networks.
- Debian official image documentation (choosing the penultimate stable release).
- MariaDB documentation — `mariadb-install-db` and server initialization.
- WordPress / WP-CLI documentation — `wp core install`, `wp config`, `wp user`.
- NGINX documentation — TLS configuration and FastCGI forwarding to php-fpm.
- Articles and discussions on running a daemon as PID 1 and on the difference
  between named volumes and bind mounts.

### Use of AI

AI (Claude) was used as a tutor and pair-programmer throughout the project. Its
role, by area:

- **Concept explanation** — clarifying Docker fundamentals (PID 1 and
  foreground processes, build-time vs runtime, the two layers of a bind-backed
  named volume, `depends_on` vs a real readiness wait) before writing any file.
- **Debugging the environment** — diagnosing setup errors on the VM (Docker not
  installed, the `docker` group and socket permissions, the misplaced `.env`,
  the `/home/lgertrud` ownership issue) and explaining the cause of each.

Every file was reviewed, understood, integrated and tested by me; the database
initialization script, in particular, was debugged and adjusted by hand after
an initial 502 error.
