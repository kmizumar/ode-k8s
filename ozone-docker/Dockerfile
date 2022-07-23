FROM pfnmaru/ozone:1.3.0-SNAPSHOT AS snapshot
FROM ubuntu:22.04

ARG UID=1000
RUN useradd -u ${UID} -g users ozone

COPY --from=snapshot --chown=ozone:users /opt/hadoop /opt/ozone
COPY --chown=ozone:users entrypoint.sh /usr/local/bin/entrypoint.sh

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -yq --no-install-recommends install \
    krb5-user \
    openjdk-11-jdk-headless \
    iputils-ping \
    net-tools \
    bind9-dnsutils \
    dumb-init \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

COPY krb5.conf /etc/krb5.conf
RUN chmod 0644 /etc/krb5.conf

ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64 \
    PATH=/opt/ozone/bin:${PATH}

USER ozone

ENTRYPOINT [ "/usr/bin/dumb-init", "--" ]
CMD [ "bash", "-c", "/usr/local/bin/entrypoint.sh" ]
