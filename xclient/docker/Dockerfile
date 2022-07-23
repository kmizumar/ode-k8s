FROM ubuntu:22.04

ARG USER=anonymous
ARG GROUP=anonymous
ARG UID=1000
ARG GID=1000

# disable prompt during package installation
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get -yq --no-install-recommends install \
    software-properties-common \
    gpg-agent && \
    add-apt-repository ppa:mozillateam/ppa && \
    apt-get update && \
    apt-get -yq --no-install-recommends install \
    krb5-user \
    firefox-esr \
 && echo 'pref("network.negotiate-auth.trusted-uris", "default.svc.cluster.local");' >> /etc/firefox-esr/syspref.js \
 && echo 'pref("browser.startup.homepage", "file:///etc/firefox/index.html");' >> /etc/firefox-esr/syspref.js \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd -g ${GID} ${GROUP} \
 && useradd -u ${UID} -g ${GROUP} -s /bin/bash -m ${USER}

COPY krb5.conf /etc/krb5.conf
COPY index.html /etc/firefox/index.html
RUN chmod 0644 /etc/krb5.conf /etc/firefox/index.html

USER ${USER}
ENV HOME /home/${USER}
WORKDIR ${HOME}

CMD [ "bash", "-c", "trap : TERM INT; (while true; do sleep 1000; done) & wait" ]
