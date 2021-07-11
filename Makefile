build:
	docker build -t galera:latest .

run:
	docker run -it galera /bin/bash
