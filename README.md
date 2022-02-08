ode-k8s
===

ode-k8s is intended to be an Ozone Develop Environment on Kubernetes.
Its purpose is to create a working environment for Apache Ozone on Kubernetes 
(hereafter referred to as k8s, as usual) for development purposes.
It is intended for development purposes,
so please DO NOT even think of using it for production.
I won't go into the details,
but there is a severe impedance mismatch between the security mechanisms currently employed by Apache Ozone and
container orchestration systems such as k8s,
so deploying Apache Ozone on k8s for enterprise use seems impractical.

The purpose of ode-k8s is to implement the following for development work towards
enterprise use of Apache Ozone

- run SCM in High Availability mode
- run OM in High Availability mode
- use of service authentication with Kerberos
- use of server authentication with TLS/SSL
- eliminate HTTP (unencrypted communication)

If you are not interested in the above items,
ode-k8s is something you don't need to care about.
You can find samples for k8s under the `kubernetes` directory of the Apache Ozone release
distributed by  the Apache Software Foundation (hereafter referred to as ASF)
and find the [Ozone on Kubernetes](https://ci-hadoop.apache.org/view/Hadoop%20Ozone/job/ozone-doc-master/lastSuccessfulBuild/artifact/hadoop-hdds/docs/public/start/kubernetes.html)
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

The custom docker image name (`pfnmaru/ozone:1.3.0-SNAPSHOT` in this example) will be used in the next step.

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

To change the docker image name, which runs in ode-k8s,
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
If you are using X Window System and can send the output screen of the browser to the display,
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

The node objects would be created as shown below when succeeded.

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

When you change the name of the docker image,
don't forget to change the container image specification embedded in each yaml file.
Since the k8s manifest specifies that images should not be brought over the network if they exist locally,
registering the necessary docker images to KinD in advance will reduce the time it takes to boot the pod.
Also, you can perform closed development without registering incomplete docker images to Docker Hub.

```shell
❯ kind load docker-image pfnmaru/krb5-client pfnmaru/krb5-server pfnmaru/ozone-runner pfnmaru/ode-xclient
```

Create a self-signed certificate authority and server certificate
---

(We can do this step independently of the operation of the KinD cluster)
By running `ansible-playbook` as follows,
the private key and certificate of the self-signed certification authority and the private key and server certificate used by each node of ode-k8s will be created under the `security/` directory.
The server certificate will be copied to the hostPath used by each node,
and the keystore/truststore in Java Key Store format will be created accordingly.

```shell
❯ ansible-playbook prepare-certs.yaml
```

Generate keytab files
---

In `kustomization.yaml`,
leave only `krb5-server/krb5-server.yaml` in the resources and comment the others out,
and comment out `keytabs` in the `configMapGenerator`.
This is to prevent kustomize from terminating with an error because the keytab files are not yet generated,
and to prevent pods that depend on MIT Kerberos from starting because the SPNs are not prepared.

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - krb5-server/krb5-server.yaml
  # - scm/scm-0.yaml
  # - scm/scm-1.yaml
  # - scm/scm-2.yaml
  # - om/om-0.yaml
  # - om/om-1.yaml
  # - om/om-2.yaml
  # - datanode/dn-0.yaml
  # - datanode/dn-1.yaml
  # - datanode/dn-2.yaml
  # - recon/recon.yaml
  # - s3gateway/s3g.yaml
configMapGenerator:
  # - name: keytabs
  #   files:
  #     - security/HTTP.keytab
  #     - security/SCM.keytab
  #     - security/OM.keytab
  #     - security/HDDS.keytab
  #     - security/RECON.keytab
  #     - security/S3G.keytab
  #   options:
  #     disableNameSuffixHash: true
  - name: krb5-script
    files:
      - krb5-server/create-db.sh
    options:
      disableNameSuffixHash: true
  - name: scm-script
    files:
      - scm/bootstrap-scm.sh
    options:
      disableNameSuffixHash: true
  - name: om-script
    files:
      - om/bootstrap-om.sh
    options:
      disableNameSuffixHash: true
...
```

Once setting up only krb5-server to start, apply this and start up the pod.

```shell
❯ k kustomize | k apply -f -
configmap/krb5-script created
configmap/om-script created
configmap/scm-script created
service/ode-kerberos created
deployment.apps/krb5-server created
```

When you are sure that krb5-server is READY,

```shell
❯ k get deploy/krb5-server
NAME          READY   UP-TO-DATE   AVAILABLE   AGE
krb5-server   1/1     1            1           37s
```

Go to the `security/` directory and run the `create-principal.sh` script to generate the SPN.
The keytab of the generated SPN will be saved in the directory where you ran the script.

```shell
❯ cd security
❯ ./create-principal.sh
```

```shell
❯ ls -lF *keytab
-rw-rw-r-- 1 maru maru  620 Jan 26 15:42 HDDS.keytab
-rw-rw-r-- 1 maru maru 2280 Jan 26 15:42 HTTP.keytab
-rw-rw-r-- 1 maru maru  608 Jan 26 15:42 OM.keytab
-rw-rw-r-- 1 maru maru  214 Jan 26 15:42 RECON.keytab
-rw-rw-r-- 1 maru maru  202 Jan 26 15:42 S3G.keytab
-rw-rw-r-- 1 maru maru  626 Jan 26 15:42 SCM.keytab
```

Start an Apache Ozone Cluster
---

Restore the lines that were commented out from the `kustomization.yaml` file when generating the keytab files.

```shell
❯ git restore kustomization.yaml
```

Apply again and wait for all pods to start working properly.

```shell
❯ k kustomize | k apply -f -
configmap/keytabs created
configmap/krb5-script unchanged
configmap/om-script unchanged
configmap/scm-script unchanged
service/dn-0 created
service/dn-1 created
service/dn-2 created
service/ode-kerberos unchanged
service/om-0 created
service/om-1 created
service/om-2 created
service/recon created
service/s3g created
service/scm-0 created
service/scm-1 created
service/scm-2 created
deployment.apps/krb5-server unchanged
pod/dn-0 created
pod/dn-1 created
pod/dn-2 created
pod/om-0 created
pod/om-1 created
pod/om-2 created
pod/recon created
pod/s3g created
pod/scm-0 created
pod/scm-1 created
pod/scm-2 created
```

If they are in this state, you can expect them to be working correctly.

![ode-k8s-pods](https://github.com/kmizumar/ode-k8s/blob/images/ode-k8s-pods.png?raw=true)


How to use ode-k8s
===

