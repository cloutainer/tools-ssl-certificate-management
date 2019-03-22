#!/bin/bash

DOMAIN_NAME=$1
SERVER_IP=$2
DOMAIN_NAME_SAFE=${DOMAIN_NAME//[*]/wildcard}

##
## DOC: Based on https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/
##


#
# CREATE CSR AND PRIVATE KEY
#
cat <<EOF | cfssl genkey - | cfssljson -bare ${DOMAIN_NAME_SAFE}
{
  "hosts": [
    "${DOMAIN_NAME}",
    "${SERVER_IP}"
  ],
  "CN": "${DOMAIN_NAME}",
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF

#
# CREATE CSR
#
cat <<EOF | kubectl create -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: csr-${DOMAIN_NAME_SAFE}
spec:
  groups:
  - system:authenticated
  request: $(cat ${DOMAIN_NAME_SAFE}.csr | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF

kubectl describe csr csr-${DOMAIN_NAME_SAFE}

#
# APPROVE CSR
#
kubectl certificate approve csr-${DOMAIN_NAME_SAFE}

#
# EXTRACT CRT
#
kubectl get csr csr-${DOMAIN_NAME_SAFE} -o jsonpath='{.status.certificate}'  | base64 --decode > ${DOMAIN_NAME_SAFE}.crt

#
# BASE64 ENCODE (one line) CRT AND KEY
#
openssl base64 -in ${DOMAIN_NAME_SAFE}-key.pem -out ssl_key_base64 -A
openssl base64 -in ${DOMAIN_NAME_SAFE}.crt -out ssl_crt_base64 -A

cp ${DOMAIN_NAME_SAFE}-key.pem ssl_key
cp ${DOMAIN_NAME_SAFE}.crt ssl_crt

#
# CREATE SECRET
#
kubectl create secret generic ssl-${DOMAIN_NAME_SAFE} --from-file=./ssl_key_base64 --from-file=./ssl_crt_base64 --from-file=./ssl_key --from-file=./ssl_crt

#
# CLEANUP
#
rm -f ssl_key_base64
rm -f ssl_crt_base64
rm -f ssl_key
rm -f ssl_crt
rm -f ${DOMAIN_NAME_SAFE}.csr
kubectl delete certificatesigningrequest csr-${DOMAIN_NAME_SAFE}
