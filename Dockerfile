FROM ubuntu:20.04

ENV  DEBIAN_FRONTEND=noninteractive

COPY mariadb-galera /opt/canonical/mariadb-galera

# Reference
# https://galeracluster.com/library/documentation/install-mariadb.html
RUN apt-get update
RUN apt-get install software-properties-common -y
RUN apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
RUN add-apt-repository 'deb [arch=amd64,arm64,ppc64el] http://ams2.mirrors.digitalocean.com/mariadb/repo/10.5/ubuntu focal main'
RUN apt-get update
RUN apt-get install mariadb-client \
      mariadb-backup \
      mariadb-server \
      galera-4 \
      prometheus-mysqld-exporter \
      pwgen \
      crudini \
      socat -y

RUN chmod g+rwX /opt/canonical/mariadb-galera/scripts
RUN /opt/canonical/mariadb-galera/scripts/prerun.sh

USER 1001
EXPOSE 3306 4444 4567 4568
ENTRYPOINT [ "/opt/canonical/mariadb-galera/scripts/entrypoint.sh" ]
CMD [ "/opt/canonical/mariadb-galera/scripts/run.sh" ]
