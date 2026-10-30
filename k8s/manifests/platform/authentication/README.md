# Kubernetes Structured Authentication

Azure kubelogin

<https://azure.github.io/kubelogin/quick-start.html>

Apply to a file on control plane nodes (e.g., /etc/kubernetes/auth-config.yaml) and update kube-apiserver static pod manifest (/etc/kubernetes/manifests/kube-apiserver.yaml) to include the following flag:

```yaml
spec:
  containers:
  - command:
    - kube-apiserver
    - --authentication-config=/etc/kubernetes/auth-config.yaml


apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-admin-oidc
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: User
  name: "" # matches username in claim
  apiGroup: rbac.authorization.k8s.io

apiVersion: kubeadm.k8s.io/v3beta3
kind: ClusterConfiguration
apiServer:
  extraArgs:
    authentication-config: /etc/kubernetes/auth-config.yaml
  extraVolumes:
  - name: auth-config
    hostPath: /etc/kubernetes/auth-config.yaml
    mountPath: /etc/kubernetes/auth-config.yaml
    readOnly: true
    pathType: File
```
