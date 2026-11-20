# OpenShift Ingress

Verify full CA chain is in the certificate

```bash
kubectl get secret console-tls -n openshift-ingress -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl crl2pkcs7 -nocrl -certfile /dev/stdin | openssl pkcs7 -print_certs -noout
```

## For staging environment

Ensure OpenShift trusts the root CA. Specifically, the custom-ca configmap in openshift-config namespace includes the root CA certificate used to sign the wildcard certificate [RouterCertsDegraded with x509 certificate signed by unknown authority in OpenShift 4](https://access.redhat.com/solutions/4542531).

<https://letsencrypt.org/docs/staging-environment/>

oc create configmap custom-ca \
--from-file=ca-bundle.crt=letsencrypt-stg-root-x1.pem \
-n openshift-config
