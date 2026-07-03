NAME    = inception
COMPOSE = docker compose -f srcs/docker-compose.yml
DATA    = /home/lgertrud/data

all: up

up:
	mkdir -p $(DATA)/mariadb $(DATA)/wordpress
	$(COMPOSE) up -d --build

build:
	$(COMPOSE) build

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

clean:
	$(COMPOSE) down -v

fclean: clean
	sudo rm -rf $(DATA)
	docker system prune -af

re: fclean all

logs:
	$(COMPOSE) logs -f

.PHONY: all up build down stop start clean fclean re logs
