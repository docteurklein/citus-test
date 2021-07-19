FROM alpine:edge as build

RUN apk add --no-cache postgresql-dev curl curl-dev make g++

RUN curl -sL https://github.com/pramsey/pgsql-http/archive/v1.3.1.tar.gz | tar xz
RUN cd pgsql-http-1.3.1 && \
    make && \
    make install

FROM alpine:edge

RUN apk add --no-cache postgresql postgresql-contrib hunspell-en

RUN cp /usr/share/hunspell/en_US.aff /usr/share/postgresql/tsearch_data/en_us.affix
RUN cp /usr/share/hunspell/en_US.dic /usr/share/postgresql/tsearch_data/en_us.dict

COPY --from=build /usr/lib/postgresql/* /usr/lib/postgresql/
COPY --from=build /usr/share/postgresql/extension/* /usr/share/postgresql/extension/

EXPOSE 5432

ARG PGDATA=/var/lib/data/postgres
ENV PGDATA=$PGDATA

ARG LANG=en_US.utf8

RUN mkdir -p $PGDATA /run/postgresql /etc/postgres && \
    chown postgres:postgres $PGDATA /run/postgresql /etc/postgres

USER postgres

RUN pg_ctl initdb -o "--locale=$LANG"

VOLUME $PGDATA

WORKDIR /usr/src/app

CMD ["postgres",  "-c", "config_file=/etc/postgres.conf"]

COPY pg_hba.conf /etc/postgres.hba
COPY postgres.conf /etc/postgres.conf
