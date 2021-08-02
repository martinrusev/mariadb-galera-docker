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

# Replace the tag on each rebuild
tag_and_push:
	docker tag d10eae68868d localhost:32000/mariadb-galera:latest
	docker push localhost:32000/mariadb-galera
