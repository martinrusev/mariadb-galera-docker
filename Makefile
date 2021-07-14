build:
	docker build -t mariadb-galera:latest .

build_nc:
	docker build -t mariadb-galera:latest . --no-cache

run:
	docker run -it mariadb-galera /bin/bash

dc:
	docker-compose up
