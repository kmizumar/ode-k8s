FROM ubuntu:20.04

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -yq --no-install-recommends install \
    krb5-kdc \
    krb5-admin-server \
    dumb-init \
    expect \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

COPY krb5.conf /etc/krb5.conf
COPY kdc.conf /etc/krb5kdc/kdc.conf
COPY kadm5.acl /etc/krb5kdc/kadm5.acl
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod 0644 /etc/krb5.conf && \
    chmod 0644 /etc/krb5kdc/kdc.conf && \
    chmod 0644 /etc/krb5kdc/kadm5.acl && \
    chmod 0755 /usr/local/bin/entrypoint.sh && \
    mkdir -p /var/log/krb5kdc && \
    chmod 0750 /var/log/krb5kdc && \
    ln -sf /lib/systemd/systemd /sbin/init

ENTRYPOINT [ "/usr/bin/dumb-init", "--" ]
CMD [ "bash", "-c", "/usr/local/bin/entrypoint.sh" ]
