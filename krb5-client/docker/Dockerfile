FROM ubuntu:20.04

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -yq --no-install-recommends install \
    krb5-user \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

COPY krb5.conf /etc/krb5.conf

RUN chmod 0644 /etc/krb5.conf

CMD [ "bash", "-c", "trap : TERM INT; (while true; do sleep 1000; done) & wait" ]
