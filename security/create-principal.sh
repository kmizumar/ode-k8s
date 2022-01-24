#!/usr/bin/env bash
set -euo pipefail

http_princs=$(cat <<EOS
HTTP/scm-0@EXAMPLE.COM
HTTP/scm-1@EXAMPLE.COM
HTTP/scm-2@EXAMPLE.COM
HTTP/_@EXAMPLE.COM
EOS
)

scm_princs=$(cat <<-EOS
SCM/scm-0@EXAMPLE.COM
SCM/scm-1@EXAMPLE.COM
SCM/scm-2@EXAMPLE.COM
SCM/_@EXAMPLE.COM
EOS
)

om_princs=$(cat <<-EOS
OM/scm-0@EXAMPLE.COM
OM/scm-1@EXAMPLE.COM
OM/scm-2@EXAMPLE.COM
OM/_@EXAMPLE.COM
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

kubectl exec deploy/krb5-server -c krb5-server -- kadmin.local -q 'ktadd -k /var/lib/krb5kdc/HTTP.keytab -glob HTTP/*@EXAMPLE.COM'
kubectl exec deploy/krb5-server -c krb5-server -- kadmin.local -q 'ktadd -k /var/lib/krb5kdc/SCM.keytab -glob SCM/*@EXAMPLE.COM'
kubectl exec deploy/krb5-server -c krb5-server -- kadmin.local -q 'ktadd -k /var/lib/krb5kdc/OM.keytab -glob OM/*@EXAMPLE.COM'
