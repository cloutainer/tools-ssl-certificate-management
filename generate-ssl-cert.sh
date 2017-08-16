#!/bin/bash

DOMAIN_NAME=$1
SERVER_IP=$2

##
## DOC: Based on https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/
##


#
# CREATE CSR AND PRIVATE KEY
#
cat <<EOF | cfssl genkey - | cfssljson -bare ${DOMAIN_NAME}
{
  "hosts": [
    "${DOMAIN_NAME}",
    "${SERVER_IP}"
  ],
  "CN": "${DOMAIN_NAME}",
  "key": {
    "algo": "ecdsa",
    "size": 256
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
  name: csr-${DOMAIN_NAME}
spec:
  groups:
  - system:authenticated
  request: $(cat ${DOMAIN_NAME}.csr | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF

kubectl describe csr csr-${DOMAIN_NAME}

#
# APPROVE CSR
#
kubectl certificate approve csr-${DOMAIN_NAME}

#
# EXTRACT CRT
#
kubectl get csr csr-${DOMAIN_NAME} -o jsonpath='{.status.certificate}'  | base64 --decode > ${DOMAIN_NAME}.crt

#
# BASE64 ENCODE (one line) CRT AND KEY
#
openssl base64 -in ${DOMAIN_NAME}-key.pem -out ssl_key_base64 -A
openssl base64 -in ${DOMAIN_NAME}.crt -out ssl_crt_base64 -A

#
# CREATE SECRET
#
kubectl create secret generic ssl-${DOMAIN_NAME} --from-file=./ssl_key_base64 --from-file=./ssl_crt_base64

#
# CLEANUP
#
rm -f ssl_key_base64
rm -f ssl_crt_base64
rm -f ${DOMAIN_NAME}.csr
