build:
	docker build -t mariadb-galera:latest .

build_nc:
	docker build -t mariadb-galera:latest . --no-cache

run:
	docker run -it mariadb-galera /bin/bash

exec:
	docker exec -it mariadb-galera-docker_mariadb-galera_1 /bin/bash

dc:
	docker-compose up

build_and_push:
	docker build -t mariadb-galera:latest .
	docker tag $(shell docker images mariadb-galera:latest --format '{{.ID}}') localhost:32000/mariadb-galera:latest
	docker push localhost:32000/mariadb-galera
