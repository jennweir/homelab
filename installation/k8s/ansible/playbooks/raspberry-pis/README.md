# Raspberry Pi Kubernetes Playbook

This playbook installs and configures Kubernetes on the Raspberry Pi nodes in the `pis` inventory group.

## Run

From the `installation/k8s/ansible` directory:

```bash
ansible-playbook \
  -i inventory \
  playbooks/raspberry-pis/install-k8s.yaml
```

The playbook installs the Kubernetes packages, configures the container runtime and CNI, initializes the control plane, joins the additional nodes, and applies Cilium.

## Kubeconfig

The control-plane kubeconfig is:

```text
/etc/kubernetes/admin.conf
```

## Control-plane scheduling

Remove the control-plane taint when workloads should run there:

```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

## Overlays

Apply platform overlays such as Argo CD, MetalLB, ingress-nginx, Kubernetes Dashboard, Longhorn, and cert-manager after the cluster is ready.
