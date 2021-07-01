FROM docker.io/bitnami/ubuntu:20.04


# Reference
# https://galeracluster.com/library/documentation/install-mariadb.html
RUN apt-get update
RUN apt-get install software-properties-common -y
RUN apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
RUN add-apt-repository 'deb [arch=amd64,arm64,ppc64el] http://ams2.mirrors.digitalocean.com/mariadb/repo/10.5/ubuntu focal main'
RUN apt-get install mariadb-client \
      mariadb-galera-server \
      galera

USER 1001
ENTRYPOINT [""]
CMD [ "" ]
