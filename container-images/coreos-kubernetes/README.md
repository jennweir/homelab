# Fedora CoreOS Kubernetes image

This image derives from Fedora CoreOS and layers CRI-O plus the Kubernetes node tools into the immutable OS deployment. The Kubernetes and CRI-O repositories are pinned to minor streams so the image does not silently switch to another Kubernetes minor version.

The image is intended for the `x86_64` lab nodes. Build it on a Linux host or inside a Podman machine:

```bash
podman pull quay.io/fedora/fedora-coreos:stable
podman image inspect \
  --format '{{range .RepoDigests}}{{println .}}{{end}}' \
  quay.io/fedora/fedora-coreos:stable

cd container-images/coreos-kubernetes
podman build \
  --build-arg FCOS_IMAGE=quay.io/fedora/fedora-coreos@sha256:7832a3499ea4c15527fdd822b69ef88ef9ea6cd2da80fc67ce34747801817b11 \
  --build-arg KUBERNETES_MINOR=v1.36 \
  --build-arg CRIO_MINOR=v1.36 \
  -t localhost/fcos-kubernetes:1.36 .
```

For repeatable builds, replace the FCOS tag with a digest from the FCOS release you have selected. Keep the Kubernetes minor stream, CRI-O minor stream, and `clusterConfiguration.yaml` aligned.

The lab ISO script exports this image as an OCI archive, adds the archive to the
ISO, and installs it automatically after FCOS is written to the NVMe disk. No
second USB, registry, SCP transfer, or manual `rpm-ostree rebase` is required.

After the installer reboots into the NVMe system, the first-boot service rebases
the installed deployment from the archive on the USB. Reboot once more after
that service completes, then verify the layered deployment and services:

```bash
rpm-ostree status
systemctl status crio kubelet
command -v kubeadm kubelet kubectl crio
```

The node-specific Butane still supplies SSH access, kernel modules, sysctls, the BPF mount, Cilium directories, and the NVMe/SATA installation policy. Run `kubeadm init` or `kubeadm join` manually after the image is installed.

The lab ISO script uses `coreos-installer iso customize` to embed the node Ignition as destination configuration and automatically install to `/dev/nvme0n1`. It intentionally does not apply that disk configuration to the live environment, where the destination's `/boot` device does not exist. Select the correct target disk before booting because installation overwrites it without another confirmation.

Each ISO build creates or replaces the key at `~/.ssh/k8s-homelab-YYYYMMDD` and injects its public key into the generated Ignition. Use the printed private-key path to connect after installation:

```bash
ssh -i ~/.ssh/k8s-homelab-YYYYMMDD core@NODE_IP
```

This workflow deliberately leaves the two SATA SSDs untouched. Configure Rook-Ceph later to select those raw devices by stable `/dev/disk/by-id` paths.
