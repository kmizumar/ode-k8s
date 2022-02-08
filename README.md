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

ode-k8s is a regular Apache Ozone cluster running on k8s, so the basics are the same.
To pass the service role authentication method used by Apache Ozone (originating from Apache Hadoop),
ode-k8s have one fixed pod per node, which allows resolution by FQDN.
Only MIT Kerberos runs as a k8s deployment, but all other Apache Ozone services run as one pod on its dedicated node.

SCM number 0 (scm-0) is primordial.


Create a user
---

Access the pod where the krb5-server deployment runs and create a user with the `kadmin.local` command.
As ode-k8s have already set up `ozone@EXAMPLE.COM` as an administrator user,
create the UPN with an appropriate password.
Kerberos REALM is `EXAMPLE.COM`.

```shell
❯ k exec -it deploy/krb5-server -c krb5-server -- bash
root@krb5-server-58c48d86b-sh8qv:/# kadmin.local
Authenticating as principal root/admin@EXAMPLE.COM with password.
kadmin.local:  addprinc ozone@EXAMPLE.COM
WARNING: no policy specified for ozone@EXAMPLE.COM; defaulting to no policy
Enter password for principal "ozone@EXAMPLE.COM":
Re-enter password for principal "ozone@EXAMPLE.COM":
Principal "ozone@EXAMPLE.COM" created.
kadmin.local:  q
root@krb5-server-58c48d86b-sh8qv:/# exit
```


Run ozone commands
---

Please note that each service of ode-k8s only has the information it needs to run itself.
For example, accessing Datanode to see OM information is impossible in the current configuration,
and I don't think it should be possible.

If you do not need to check the information of each instance of each service,
it is recommended to operate via OM since it has a broader range of information.
(You can also prepare a dedicated client).

```shell
❯ k exec -it po/om-0 -c om -- bash
ozone@om-0:/$ kinit ozone@EXAMPLE.COM
Password for ozone@EXAMPLE.COM:
ozone@om-0:/$ ozone admin scm roles
scm-0.scm-0.default.svc.cluster.local:9894:LEADER:b109cac2-3bd5-4ae8-8bf0-6d8c1bb84a70
scm-2.scm-2.default.svc.cluster.local:9894:FOLLOWER:c0db0f4d-4429-4dfd-9077-d4ce39ed5efc
scm-1.scm-1.default.svc.cluster.local:9894:FOLLOWER:d40ba86a-c86e-417c-830f-2c9c16259e6b
ozone@om-0:/$ ozone admin om roles -id=omservice
om-1 : FOLLOWER (om-1.om-1.default.svc.cluster.local)
om-2 : FOLLOWER (om-2.om-2.default.svc.cluster.local)
om-0 : LEADER (om-0.om-0.default.svc.cluster.local)
ozone@om-0:/$ ozone admin datanode list
Datanode: 9438d617-48cb-40a9-b2e5-62ceecd75bdf (/default-rack/10.244.7.2/dn-1.dn-1.default.svc.cluster.local/3 pipelines)
Operational State: IN_SERVICE
Health State: HEALTHY
Related pipelines:
7df09e71-a107-4890-8289-88b7a15c5b2c/RATIS/ONE/RATIS/OPEN/Leader
c948283b-db42-4899-873a-260e60355565/RATIS/THREE/RATIS/ALLOCATED/Follower
b99fcbdf-9a71-4b7d-8bd5-2af1271592d0/RATIS/THREE/RATIS/ALLOCATED/Follower

Datanode: f0d720c8-be6f-4251-b55b-cd72acfeaeb5 (/default-rack/10.244.12.2/dn-2.dn-2.default.svc.cluster.local/3 pipelines)
Operational State: IN_SERVICE
Health State: HEALTHY
Related pipelines:
e705d9e3-8b68-4a42-be12-02cd34d4d343/RATIS/ONE/RATIS/OPEN/Leader
c948283b-db42-4899-873a-260e60355565/RATIS/THREE/RATIS/ALLOCATED/Follower
b99fcbdf-9a71-4b7d-8bd5-2af1271592d0/RATIS/THREE/RATIS/ALLOCATED/Follower

Datanode: 13cd967a-649b-4f92-b5df-7f5777cdf86f (/default-rack/10.244.1.2/dn-0.dn-0.default.svc.cluster.local/3 pipelines)
Operational State: IN_SERVICE
Health State: HEALTHY
Related pipelines:
da793283-bf81-48bd-b4ab-592ab651ee02/RATIS/ONE/RATIS/OPEN/Leader
c948283b-db42-4899-873a-260e60355565/RATIS/THREE/RATIS/ALLOCATED/Follower
b99fcbdf-9a71-4b7d-8bd5-2af1271592d0/RATIS/THREE/RATIS/ALLOCATED/Follower
```

Access to S3 Gateway
---

The S3 Gateway is listening on port 9879 of the s3g pod.
Execute the `ozone s3 getsecret` command while `kinit` with the UPN of the user you want to access.
Specifying the `-e` option is convenient since the output will be in a format that can be used for setting environment variables.

```shell
❯ k exec -it po/om-0 -c om -- bash
ozone@om-0:/$ kinit kmizumar@EXAMPLE.COM
Password for kmizumar@EXAMPLE.COM:
ozone@om-0:/$ ozone s3 getsecret -e --om-service-id=omservice
export AWS_ACCESS_KEY_ID=kmizumar@EXAMPLE.COM
export AWS_SECRET_ACCESS_KEY=6d6ed47bd70a5ec144ba2d5c41e03586ba106d46e4b685feaff69939566e57e1
ozone@om-0:/$
```

In addition to `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`,
set `AWS_CA_BUNDLE` environment variable to accept a self-signed Certificate Authority certificate.
Change the path to the `ode-k8s/security/` directory as needed.

```shell
export AWS_CA_BUNDLE=/home/maru/IdeaProjects/ode-k8s/security/CA.cert
```

Add a line to the `/etc/hosts` file so that the FQDN of the S3 Gateway node points to 127.0.0.1.

```shell
127.0.0.1 localhost
(snip)

# ode-k8s
127.0.0.1 s3g.s3g.default.svc.cluster.local
```

Open another terminal and run `port-forward` to port 9879 of s3g pod.

```shell
❯ k port-forward s3g 9879:9879
Forwarding from 127.0.0.1:9879 -> 9879
Forwarding from [::1]:9879 -> 9879
```

Access through the S3 protocol is available by specifying the endpoint appropriately.

```shell
❯ aws s3 ls --endpoint-url https://s3g.s3g.default.svc.cluster.local:9879 s3://test-bucket/
2022-02-04 14:37:17        360 ansible.cfg
```

Please note that access with the endpoint `http://localhost:9879` will be rejected by SSL validation.

```shell
❯ aws s3 ls --endpoint-url https://localhost:9879 s3://test-bucket/

SSL validation failed for https://localhost:9879/test-bucket?list-type=2&prefix=&delimiter=%2F&encoding-type=url ("hostname 'localhost' doesn't match 's3g.s3g.default.svc.cluster.local'",)
```

Access to WebUI
---

We want access to Recon and other WebUIs from outside ode-k8s,
but it is troublesome to make the client-side join the same Kerberos REALM to get tickets and resolve node names.
To avoid dealing with these issues,
I decided to run the web browser in the same network as ode-k8s and display the screen on the X Display Server at hand.

First, check to see if the DISPLAY environment variable is set.

```shell
❯ echo $DISPLAY
:0
```

Continue to start the xclient pod.

```shell
❯ k apply -f xclient/
configmap/xclient created
pod/xclient created
```

Once you've confirmed that the pod is READY

```shell
❯ k get po/xclient
NAME      READY   STATUS    RESTARTS   AGE
xclient   1/1     Running   0          110s
```

Access pod with kubectl exec and prepare for SPNEGO

```shell
❯ k exec -it po/xclient -- bash
maru@xclient:~$ kinit kmizumar@EXAMPLE.COM
Password for kmizumar@EXAMPLE.COM:
maru@xclient:~$ klist -fae
Ticket cache: FILE:/tmp/krb5cc_1000
Default principal: kmizumar@EXAMPLE.COM

Valid starting     Expires            Service principal
02/07/22 10:15:32  02/14/22 10:15:30  krbtgt/EXAMPLE.COM@EXAMPLE.COM
	renew until 03/07/22 10:15:30, Flags: FRIA
	Etype (skey, tkt): aes256-cts-hmac-sha1-96, aes256-cts-hmac-sha1-96
	Addresses: (none)
maru@xclient:~$
```

Launch firefox

```shell
maru@xclient:~$ firefox
Gtk-Message: 10:16:47.394: Failed to load module "canberra-gtk-module"
Gtk-Message: 10:16:47.395: Failed to load module "canberra-gtk-module"
[GFX1-]: glxtest: libpci missing
[GFX1-]: glxtest: libEGL missing
[GFX1-]: glxtest: libGL.so.1 missing
[GFX1-]: glxtest: libEGL missing
[GFX1-]: No GPUs detected via PCI
```

I've set up the page we want to access first, but I think this screen shows up.
If anyone knows how to fix this, please let me know.

![firefox-welcome](https://github.com/kmizumar/ode-k8s/blob/images/firefox-welcome.png?raw=true)

Since we have no use for this page, click the X button on the browser to close it.
Note that if you stop by hitting ^C, it seems to stay in the same state.
It seems to be OK when we see the following message.

```shell
###!!! [Child][RunMessage] Error: Channel closing: too late to send/recv, messages will be lost


###!!! [Parent][RunMessage] Error: Channel closing: too late to send/recv, messages will be lost

maru@xclient:~$
```

Launch firefox again.

```shell
maru@xclient:~$ firefox
Gtk-Message: 10:22:14.709: Failed to load module "canberra-gtk-module"
Gtk-Message: 10:22:14.710: Failed to load module "canberra-gtk-module"
[GFX1-]: glxtest: libpci missing
[GFX1-]: glxtest: libEGL missing
[GFX1-]: glxtest: libGL.so.1 missing
[GFX1-]: glxtest: libEGL missing
[GFX1-]: No GPUs detected via PCI
```

If you see a screen like this, you have succeeded.

![ode-k8s-endpoints](https://github.com/kmizumar/ode-k8s/blob/images/ode-k8s-endpoints.png?raw=true)

Since ode-k8s is set to HTTPS_ONLY, select a destination to access from HTTPS Endpoints.
A warning message comes that there is a security concern because we are using a self-signed certificate, but ignore it and proceed.

![firefox-warning](https://github.com/kmizumar/ode-k8s/blob/images/firefox-warning.png?raw=true)

We can access the WebUI of Recon, SCM, OM and Datanode.

![ode-k8s-recon](https://github.com/kmizumar/ode-k8s/blob/images/ode-k8s-recon.png?raw=true)


How to stop ode-k8s
===

Stopping ode-k8s is the same as erasing the object with normal k8s:

```shell
❯ k kustomize | k delete -f -                                                                                                                            ✘ 255 
configmap "keytabs" deleted
configmap "krb5-script" deleted
configmap "om-script" deleted
configmap "scm-script" deleted
service "dn-0" deleted
service "dn-1" deleted
service "dn-2" deleted
service "ode-kerberos" deleted
service "om-0" deleted
service "om-1" deleted
service "om-2" deleted
service "recon" deleted
service "s3g" deleted
service "scm-0" deleted
service "scm-1" deleted
service "scm-2" deleted
deployment.apps "krb5-server" deleted
pod "dn-0" deleted
pod "dn-1" deleted
pod "dn-2" deleted
pod "om-0" deleted
pod "om-1" deleted
pod "om-2" deleted
pod "recon" deleted
pod "s3g" deleted
pod "scm-0" deleted
pod "scm-1" deleted
pod "scm-2" deleted
```

The xclient pod is not included in the `kusbomization.yaml`, so please delete it separately.

```shell
❯ k delete -f xclient/
configmap "xclient" deleted
pod "xclient" deleted
```

The method to delete a KinD cluster is the same as usual.
If you changed the cluster name, please specify the target cluster name.

```shell
❯ kind delete cluster --name kind                                                                                                                          ✘ 1 
Deleting cluster "kind" ...
```
