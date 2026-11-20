# bm okd install

<https://github.com/okd-project/okd/releases>

```bash
export OPENSHIFT_INSTALL_OS_IMAGE_OVERRIDE="https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/pre-release/latest/rhcos-live-iso.x86_64.iso"

./openshift-install-linux-4.19.0-okd-scos.17/openshift-install --dir configs agent create image
```

## copy iso to usb

```bash
lsblk
umount /dev/sdX
sudo dd if=agent.x86_64.iso of=/dev/sda bs=1M status=progress
sync
```

## once iso loaded into each box

```bash
export KUBECONFIG=~/Projects/HomeLab/okd-install/configs/auth/kubeconfig
./openshift-install-linux-4.19.0-okd-scos.17/openshift-install --dir configs agent wait-for bootstrap-complete
./openshift-install-linux-4.19.0-okd-scos.17/openshift-install --dir configs agent wait-for install-complete
```
