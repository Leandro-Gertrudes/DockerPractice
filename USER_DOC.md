# User Documentation

This document explains how to run and use the Inception stack as an end user or
administrator. It assumes the environment is already set up. For a setup from
scratch, see `DEV_DOC.md`.

## What the stack provides

The project runs three services, each in its own container:

- **NGINX** is the web server and the only entry point. It answers on HTTPS
  (port 443) using TLS 1.2 or 1.3, and forwards dynamic requests to WordPress.
- **WordPress (with php-fpm)** is the website itself, including its
  administration panel.
- **MariaDB** is the database that stores all WordPress content (posts, users,
  settings).

The website is available at **https://lgertrud.42.fr**.

## Start and stop the project

All commands are run from the repository root.

- **Start everything:** `make`
  Builds the images if needed and starts the three containers in the background.
- **Stop and remove the containers:** `make down`
  The data is preserved, so a later `make` brings the site back exactly as it
  was.
- **Pause and resume without removing containers:** `make stop` and `make start`.
- **Follow what the services are doing:** `make logs` (press `Ctrl+C` to stop
  watching, which does not stop the containers).

The first `make` takes a minute or two, because WordPress downloads and installs
itself on first boot. Wait until the logs show that WordPress installation is
complete before opening the site, otherwise the browser may briefly show a 502
error.

## Access the website and the administration panel

- **Website:** open **https://lgertrud.42.fr** in a browser on the host.
- **Administration panel:** open **https://lgertrud.42.fr/wp-admin**.

The browser will warn that the connection is not private. This is expected,
because the TLS certificate is self-signed for local use. Choose the advanced
option and proceed to the site. Note that only HTTPS works, since port 443 is
the only one open. A plain `http://` address will not load.

Two WordPress accounts exist:

- **Administrator:** username `boss` (full control of the site).
- **Regular user:** username `visitant` (subscriber, limited permissions).

## Locate and manage credentials

All passwords live in the `secrets/` folder at the repository root, one password
per file:

- `secrets/db_root_password.txt` is the MariaDB root password.
- `secrets/db_password.txt` is the password of the database user (`lger`).
- `secrets/wp_admin_password.txt` is the password of the WordPress administrator
  (`boss`).
- `secrets/wp_user_password.txt` is the password of the second WordPress user
  (`visitant`).

To read a password, print the file, for example:

```bash
cat secrets/wp_admin_password.txt
```

These files are kept out of Git (the `secrets/` folder is in `.gitignore`), so
they never leave the machine.

Changing a credential: the passwords are applied when a service initializes for
the first time. The simplest way to change the admin password of an existing
site is from inside the WordPress panel (Users section). To change the database
or initial passwords through the secret files, edit the file and then rebuild
from a clean state with `make re`, which recreates the stack from scratch and
applies the new values (this also erases existing data).

## Check that the services are running correctly

- **See the running containers and their status:**

  ```bash
  docker ps
  ```

  The three containers (`nginx`, `wordpress`, `mariadb`) should show a status of
  `Up`. A status of `Restarting` means a container is crashing and being
  restarted in a loop, which indicates a problem.

- **Read the logs to confirm a healthy start:**

  ```bash
  make logs
  ```

  A healthy start shows MariaDB initializing, then WordPress waiting for the
  database, connecting, and finishing its installation.

- **Confirm the site answers:** open **https://lgertrud.42.fr** and check that
  the WordPress site loads, then log in at `/wp-admin`.
