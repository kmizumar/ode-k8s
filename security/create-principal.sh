#!/usr/bin/env bash
set -euo pipefail

http_princs=$(cat <<EOS
HTTP/_@EXAMPLE.COM
EOS
)

scm_princs=$(cat <<-EOS
SCM/_@EXAMPLE.COM
EOS
)

om_princs=$(cat <<-EOS
OM/_@EXAMPLE.COM
EOS
)

dfs_princs=$(cat <<-EOS
HDDS/_@EXAMPLE.COM
EOS
)

recon_princs=$(cat <<-EOS
RECON/_@EXAMPLE.COM
EOS
)

s3g_princs=$(cat <<-EOS
S3G/_@EXAMPLE.COM
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
