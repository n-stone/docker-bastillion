FROM golang:1.17-bullseye AS dockerize
WORKDIR /go/src/github.com/jwilder/dockerize
ADD https://github.com/n-stone/dockerize/archive/refs/tags/v0.6.2.tar.gz /tmp/
RUN tar xzf /tmp/v0.6.2.tar.gz -C /tmp/ && \
    mv /tmp/dockerize-0.6.2/* /go/src/github.com/jwilder/dockerize/

ENV GO111MODULE=on
RUN go mod tidy
RUN go install

FROM debian:bullseye-slim
LABEL maintainer="Nils Stein <social.nstein@mailbox.org>"

ARG BASTILLION_VERSION
ARG BASTILLION_FILENAME_VERSION

ENV BASTILLION_VERSION=${BASTILLION_VERSION} \
    BASTILLION_FILENAME=${BASTILLION_FILENAME_VERSION}

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install --no-install-recommends -y \
        openjdk-11-jre-headless && \
    apt-get -y autoremove && \
    apt-get clean autoclean && \
    rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*

ADD https://github.com/bastillion-io/Bastillion/releases/download/v${BASTILLION_VERSION}/bastillion-jetty-v${BASTILLION_FILENAME}.tar.gz /tmp/

COPY --from=dockerize /go/bin/dockerize /usr/local/bin

RUN tar xzf /tmp/bastillion-jetty-v${BASTILLION_FILENAME}.tar.gz -C /opt && \
    mv /opt/Bastillion-jetty /opt/bastillion && \
    rm /tmp/bastillion-jetty-v${BASTILLION_FILENAME}.tar.gz && \
    mkdir /opt/bastillion/jetty/bastillion/WEB-INF/classes/keydb && \
    ln -s /opt/bastillion/jetty/bastillion/WEB-INF/classes/keydb /keydb && \
    rm /opt/bastillion/jetty/bastillion/WEB-INF/classes/BastillionConfig.properties

ADD files/BastillionConfig.properties.tpl /opt
ADD files/jetty-start.ini /opt/bastillion/jetty/start.ini
ADD files/startBastillion.sh /opt/bastillion/startBastillion.sh

RUN useradd --system --no-create-home --user-group --home-dir /opt/bastillion --shell /bin/bash --uid 999 bastillion && \
    chmod 755 /opt/bastillion/startBastillion.sh && \
    chown -R 999:999 /opt/bastillion && \
    chmod -R g=u /opt/bastillion

VOLUME /keydb
WORKDIR /opt/bastillion
EXPOSE 8443
USER 999

ENTRYPOINT ["/usr/local/bin/dockerize"]
CMD ["-template", \
     "/opt/BastillionConfig.properties.tpl:/opt/bastillion/jetty/bastillion/WEB-INF/classes/BastillionConfig.properties", \
     "/opt/bastillion/startBastillion.sh"]
