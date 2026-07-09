NAME    = inception
COMPOSE = docker compose -f srcs/docker-compose.yml
BONUS   = --profile bonus
DATA    = /home/lgertrud/data

all: up

up:
	mkdir -p $(DATA)/mariadb $(DATA)/wordpress
	$(COMPOSE) up -d --build

bonus:
	mkdir -p $(DATA)/mariadb $(DATA)/wordpress $(DATA)/uptime-kuma
	$(COMPOSE) $(BONUS) up -d --build
	$(COMPOSE) restart wordpress

build:
	$(COMPOSE) build

down:
	$(COMPOSE) $(BONUS) down

stop:
	$(COMPOSE) $(BONUS) stop

start:
	$(COMPOSE) $(BONUS) start

clean:
	$(COMPOSE) $(BONUS) down -v

fclean: clean
	sudo rm -rf $(DATA)
	docker system prune -af

re: fclean all

logs:
	$(COMPOSE) $(BONUS) logs -f

.PHONY: all up bonus build down stop start clean fclean re logs
