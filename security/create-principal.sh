#!/usr/bin/env bash
set -euo pipefail

http_princs=$(cat <<EOS
HTTP/scm-0.scm-0.default.svc.cluster.local@EXAMPLE.COM
HTTP/scm-1.scm-1.default.svc.cluster.local@EXAMPLE.COM
HTTP/scm-2.scm-2.default.svc.cluster.local@EXAMPLE.COM
HTTP/om-0.om-0.default.svc.cluster.local@EXAMPLE.COM
HTTP/om-1.om-1.default.svc.cluster.local@EXAMPLE.COM
HTTP/om-2.om-2.default.svc.cluster.local@EXAMPLE.COM
HTTP/dn-0.dn-0.default.svc.cluster.local@EXAMPLE.COM
HTTP/dn-1.dn-1.default.svc.cluster.local@EXAMPLE.COM
HTTP/dn-2.dn-2.default.svc.cluster.local@EXAMPLE.COM
HTTP/recon.recon.default.svc.cluster.local@EXAMPLE.COM
HTTP/s3g.s3g.default.svc.cluster.local@EXAMPLE.COM
EOS
)

scm_princs=$(cat <<-EOS
SCM/scm-0.scm-0.default.svc.cluster.local@EXAMPLE.COM
SCM/scm-1.scm-1.default.svc.cluster.local@EXAMPLE.COM
SCM/scm-2.scm-2.default.svc.cluster.local@EXAMPLE.COM
EOS
)

om_princs=$(cat <<-EOS
OM/om-0.om-0.default.svc.cluster.local@EXAMPLE.COM
OM/om-1.om-1.default.svc.cluster.local@EXAMPLE.COM
OM/om-2.om-2.default.svc.cluster.local@EXAMPLE.COM
EOS
)

dfs_princs=$(cat <<-EOS
HDDS/dn-0.dn-0.default.svc.cluster.local@EXAMPLE.COM
HDDS/dn-1.dn-1.default.svc.cluster.local@EXAMPLE.COM
HDDS/dn-2.dn-2.default.svc.cluster.local@EXAMPLE.COM
EOS
)

recon_princs=$(cat <<-EOS
RECON/recon.recon.default.svc.cluster.local@EXAMPLE.COM
EOS
)

s3g_princs=$(cat <<-EOS
S3G/s3g.s3g.default.svc.cluster.local@EXAMPLE.COM
EOS
)

function create_spn
{
    declare princs=${@}
    for spn in ${princs}; do
        kubectl exec deploy/krb5-server -c krb5-server -- kadmin.local -q "addprinc -randkey ${spn}"
    done
}

create_spn ${http_princs}
create_spn ${scm_princs}
create_spn ${om_princs}
create_spn ${dfs_princs}
create_spn ${recon_princs}
create_spn ${s3g_princs}

kubectl exec deploy/krb5-server -c krb5-server -- kadmin.local -q 'ktadd -k /var/lib/krb5kdc/HTTP.keytab -glob HTTP/*@EXAMPLE.COM'
kubectl exec deploy/krb5-server -c krb5-server -- kadmin.local -q 'ktadd -k /var/lib/krb5kdc/SCM.keytab -glob SCM/*@EXAMPLE.COM'
kubectl exec deploy/krb5-server -c krb5-server -- kadmin.local -q 'ktadd -k /var/lib/krb5kdc/OM.keytab -glob OM/*@EXAMPLE.COM'
kubectl exec deploy/krb5-server -c krb5-server -- kadmin.local -q 'ktadd -k /var/lib/krb5kdc/HDDS.keytab -glob HDDS/*@EXAMPLE.COM'
kubectl exec deploy/krb5-server -c krb5-server -- kadmin.local -q 'ktadd -k /var/lib/krb5kdc/RECON.keytab -glob RECON/*@EXAMPLE.COM'
kubectl exec deploy/krb5-server -c krb5-server -- kadmin.local -q 'ktadd -k /var/lib/krb5kdc/S3G.keytab -glob S3G/*@EXAMPLE.COM'
