build:
	docker build -t mariadb-galera:latest .

run:
	docker run -it mariadb-galera /bin/bash

dc:
	docker-compose up
