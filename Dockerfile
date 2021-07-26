FROM ubuntu:21.04

ENV  DEBIAN_FRONTEND=noninteractive

COPY mariadb-galera /opt/canonical/mariadb-galera

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
