ode-k8s
===

ode-k8s is intended to be an Ozone Develop Environment on Kubernetes.
Its purpose is to create a working environment for Apache Ozone on Kubernetes 
(hereafter referred to as k8s, as usual) for development purposes.
Its is intended for development purposes, 
so please DO NOT even think of using it for production.
I won't go into details, 
but there is a serious impedance mismatch between the security mechanisms currently employed by Apache Ozone and
container orchestration systems such as k8s,
so deploying Apache Ozone on k8s for enterprise use seems impractical.

The purpose of ode-k8s to implement the following for development work towards
enterprise use of Apache Ozone

- run SCM in High Availability mode
- run OM in High Availability mode
- use of service authentication with Kerberos
- use of server authentication with TLS/SSL
- eliminate HTTP (unencrypted communication)

If you are not interested in the above items,
ode-k8s is something you don't need to care of.
You can find samples for k8s under the `kubernetes`directory of the Apache Ozone release
distributed by  the Apache Software Foundation (hereafter referred to as ASF),
and also find the [Ozone on Kubernetes](https://ci-hadoop.apache.org/view/Hadoop%20Ozone/job/ozone-doc-master/lastSuccessfulBuild/artifact/hadoop-hdds/docs/public/start/kubernetes.html)
section on the official documentation. 


Requirements
===

The following is a list of items required to ode-k8s.

- [ode-k8s](https://github.com/kmizumar/ode-k8s)
- [Apache Ozone](https://github.com/apache/ozone)
- [kind](https://github.com/kubernetes-sigs/kind)
- [ansible](https://github.com/ansible/ansible)

Not sure about which versions are required, but I'm running ode-k8s with

- Apache Ozone 1.3.0-SNAPSHOT
- kind v0.11.1 go1.17.5 linux/amd64
- Docker Engine - Community 20.10.12
- ansible 5.2.0, ansible-core 2.12.1
- Ubuntu 20.04.3 LTS


How to set up ode-k8s
===

Build the Apache Ozone binary you want to check
---

Consult the ASF's Apache Ozone site and the documents included in the Apache Ozone repository for the details.
What we need is a docker image with our custom build binary files.

```shell
~/IdeaProjects/ozone master* maru@s500plus 5m 36s
❯ mvn -Pdocker-build -Ddocker.image=pfnmaru/ozone:1.3.0-SNAPSHOT -DskipTests -Pdist clean package

(snip)

[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  05:34 min
[INFO] Finished at: 2022-02-07T02:23:36Z
[INFO] ------------------------------------------------------------------------
```

The custom docker image name (`pfnmaru/ozone:1.3.0-SNAPSHOT` in this example) will be used the next step.

Build docker images you want to run in ode-k8s
---

Edit the first line of `ozone-docker/Dockerfile` to pick files under the `/opt/hadoop` directory of
the docker image you built.

```dockerfile
FROM pfnmaru/ozone:1.3.0-SNAPSHOT AS snapshot
FROM ubuntu:20.04

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
```

In order to change the docker image name which runs in ode-k8s, 
please edit the last line of `ozone-docker/build.sh` script accordingly.

```shell
#!/usr/bin/env bash
set -eu
cd "$(dirname "${BASH_SOURCE[0]}")"
docker build . -t pfnmaru/ozone-runner
```

Build the docker image by executing the `build.sh` script.

```shell
❯ ./ozone-docker/build.sh
```

For docker images that do not depend on the Apache Ozone binary,
we can do the same by executing the `build.sh` script that is stored in each directory.
The same goes for how to change the generated docker image name.

```shell
❯ ./krb5-server/docker/build.sh
```
```shell
❯ ./xclient/docker/build.sh
```
```shell
❯ ./krb5-client/docker/build.sh
```
krb5-client can be omitted because it is for MIT Kerberos client testing and is not a required component for ode-k8s.


Create a KinD cluster
---

Use the `create-kind-cluster.sh` script to create a KinD cluster.
If you are using X Window System and are able to send the output screen of the browser to the display,
you can start an additional worker node for xclient by specifying the `--with-xclient` option.

```shell
❯ ./create-kind-cluster.sh --with-xclient
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.23.1) 🖼
 ✓ Preparing nodes 📦 📦 📦 📦 📦 📦 📦 📦 📦 📦 📦 📦 📦 📦  
 ✓ Writing configuration 📜 
 ✓ Starting control-plane 🕹️ 
 ✓ Installing CNI 🔌 
 ✓ Installing StorageClass 💾 
 ✓ Joining worker nodes 🚜 
Set kubectl context to "kind-kind"
You can now use your cluster with:

kubectl cluster-info --context kind-kind

Not sure what to do next? 😅  Check out https://kind.sigs.k8s.io/docs/user/quick-start/
configmap/coredns patched
```

The node objects would be created as show below when succeeded.

```shell
❯ k get nodes
NAME                 STATUS   ROLES                  AGE     VERSION
kind-control-plane   Ready    control-plane,master   2m31s   v1.23.1
ode-dn0              Ready    <none>                 2m11s   v1.23.1
ode-dn1              Ready    <none>                 118s    v1.23.1
ode-dn2              Ready    <none>                 118s    v1.23.1
ode-kerberos         Ready    <none>                 118s    v1.23.1
ode-om0              Ready    <none>                 118s    v1.23.1
ode-om1              Ready    <none>                 118s    v1.23.1
ode-om2              Ready    <none>                 118s    v1.23.1
ode-recon            Ready    <none>                 118s    v1.23.1
ode-s3g              Ready    <none>                 118s    v1.23.1
ode-scm0             Ready    <none>                 2m11s   v1.23.1
ode-scm1             Ready    <none>                 2m11s   v1.23.1
ode-scm2             Ready    <none>                 118s    v1.23.1
ode-xclient          Ready    <none>                 118s    v1.23.1
```

Load docker images into KinD's local repository
---

