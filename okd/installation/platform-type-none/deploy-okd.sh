#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

RED="\e[31m"
GREEN="\e[32m"
RESET="\e[0m"

# This script automates the deployment of an OKD cluster with a bootstrap node and user provisioned infrastructure (UPI) with platform: none
# https://docs.okd.io/4.17/installing/installing_bare_metal/installing-bare-metal.html
# https://github.com/okd-project/okd/releases
# https://docs.okd.io/4.18/installing/overview/index.html#ocp-installation-overview

OKD_INSTALL_DIR=~/Projects/HomeLab/okd/install
PHY_SSH_KEY=~/.ssh/id_rsa_homelab_phy_boxes
CORE_SSH_KEY=~/.ssh/okd-cluster-key
WEBSERVER_K8S_KUBECONFIG=~/Projects/HomeLab/.kube/pi-kubeconfig
WEBSERVER_PATH="http://webserver.homelab.jenniferpweir.com"
OKD_DOMAIN="okd.jenniferpweir.com"
PHY_BOX_1="box-1.homelab.jenniferpweir.com"
PHY_BOX_2="box-2.homelab.jenniferpweir.com"
PHY_BOX_3="box-3.homelab.jenniferpweir.com"
OC_CLI="https://github.com/okd-project/okd-scos/releases/download/4.18.0-okd-scos.6/openshift-client-mac-4.18.0-okd-scos.6.tar.gz"
OCP_INSTALLER="https://github.com/okd-project/okd-scos/releases/download/4.18.0-okd-scos.6/openshift-install-mac-4.18.0-okd-scos.6.tar.gz"

# Prerequisites
echo -e "${GREEN}1. Check the required DNS entries resolve with forward and reverse DNS${RESET}"
okd_required_dns_entries=(
    "api.${OKD_DOMAIN}"
    "api-int.${OKD_DOMAIN}"
    "test.apps.${OKD_DOMAIN}"
    "bootstrap.${OKD_DOMAIN}"
    "cp-1.${OKD_DOMAIN}"
    "cp-2.${OKD_DOMAIN}"
    "cp-3.${OKD_DOMAIN}"
    "worker-1.${OKD_DOMAIN}"
    "worker-2.${OKD_DOMAIN}"
    "worker-3.${OKD_DOMAIN}"
)

for dns_entry in "${okd_required_dns_entries[@]}"; do
    # Perform forward DNS lookup
    ip_address=$(nslookup "$dns_entry" | awk '/^Address: / { print $2 }')
    if [[ -z "$ip_address" ]]; then
        echo -e "${RED}Error: Forward DNS lookup failed for $dns_entry. Check DNS configs.${RESET}"
        exit 1
    else
        echo "Forward DNS lookup for $dns_entry resolved to $ip_address"
    fi

    # Perform reverse DNS lookup
    reverse_dns=$(nslookup "$ip_address")
    echo "Reverse DNS lookup for $ip_address resolved to $reverse_dns"
done

echo -e "${GREEN}2. Check load balancing for the api server, machine config server, and ingress${RESET}"
ports=(22623 6443 80 443)
for port in "${ports[@]}"; do
    echo "Checking load balancer on port $port..."
    if ! nc -zv keepalived.okd.jenniferpweir.com "$port"; then
        echo -e "${RED}Error: Load balancer check failed on port $port. Exiting.${RESET}"
        exit 1
    else
        echo "Load balancer check succeeded on port $port."
    fi
done

echo -e "${GREEN}3. Prepare the environment${RESET}"
# Create directory for okd install
mkdir -p "${OKD_INSTALL_DIR}"
cd "${OKD_INSTALL_DIR}"
# Download the OKD installer and client (4.17.0-okd-scos.0)

curl -L -o openshift-install.tar.gz "${OCP_INSTALLER}"
# Check if the download was successful
if [[ ! -f "openshift-install.tar.gz" ]]; then
    echo -e "${RED}Error: Failed to download the OpenShift installer. Exiting.${RESET}"
    exit 1
fi
# Extract the OpenShift installer
tar -xvf openshift-install.tar.gz

curl -L -o oc.tar.gz "${OC_CLI}"
# Check if the download was successful
if [[ ! -f "oc.tar.gz" ]]; then
    echo -e "${RED}Error: Failed to download the OpenShift CLI (oc). Exiting.${RESET}"
    exit 1
fi
# Extract the OpenShift CLI (oc)
tar -xvf oc.tar.gz
sudo mv oc /usr/local/bin/

# Check if the OpenShift CLI (oc) is installed
if ! command -v oc &> /dev/null; then
    echo -e "${RED}Error: The OpenShift CLI (oc) is not installed or not in the PATH. Exiting.${RESET}"
    exit 1
else
    echo "The OpenShift CLI (oc) is installed."
    # Optionally, verify the version
    oc version --client
fi

# Replace the pull secret in install-config.yaml
if [[ -f "install-config-template.yaml" && -f "pull-secret.txt" ]]; then
    echo "Creating install-config.yaml from template..."
    cp install-config-template.yaml install-config.yaml
    echo "Replacing pull secret in install-config.yaml with contents from pull-secret.txt..."
    pull_secret=$(cat pull-secret.txt | tr -d '\n' | jq -c .)
    escaped_pull_secret=$(echo "$pull_secret" | sed 's/"/\\"/g')
    yq -i ".pullSecret = \"$escaped_pull_secret\"" install-config.yaml
    echo "Pull secret replaced successfully."
else
    echo -e "${RED}Error: Either install-config.yaml or pull-secret.txt is missing. Exiting.${RESET}"
    exit 1
fi

# Generate cluster ssh key
ssh-keygen -t ecdsa -N '' -f "${CORE_SSH_KEY}"
# Add the public key to the install-config.yaml
if [[ -f "install-config.yaml" && -f ~/.ssh/okd-cluster-key.pub ]]; then
    echo "Adding public SSH key to install-config.yaml..."
    public_key=$(cat "${CORE_SSH_KEY}.pub" | tr -d '\n')
    escaped_public_key=$(echo "$public_key" | sed 's/"/\\"/g')
    yq -i ".sshKey = \"$escaped_public_key\"" install-config.yaml
    echo "Public SSH key added successfully."
else
    echo -e "${RED}Error: Either install-config.yaml or the SSH public key is missing. Exiting.${RESET}"
    exit 1
fi

if [[ -f "coreos-ssh-template.yaml" && -f ~/.ssh/okd-cluster-key.pub ]]; then
    echo "Creating coreos-ssh.yaml from template..."
    cp coreos-ssh-template.yaml coreos-ssh.yaml
    echo "Replacing public SSH key in coreos-ssh.yaml with contents from ~/.ssh/okd-cluster-key.pub..."
    public_key=$(cat "${CORE_SSH_KEY}.pub" | tr -d '\n')
    escaped_public_key=$(echo "$public_key" | sed 's/"/\\"/g')
    yq -i ".passwd.users[0].ssh_authorized_keys[0] = \"$escaped_public_key\"" coreos-ssh.yaml
    echo "Public SSH key added successfully."
else
    echo -e "${RED}Error: Either coreos-ssh.yaml or the SSH public key is missing. Exiting.${RESET}"
    exit 1
fi

butane --pretty --strict coreos-ssh.yaml > coreos-ssh.ign

echo -e "${GREEN}4. Create Kubernetes manifests${RESET}"
mkdir -p "${OKD_INSTALL_DIR}"
./openshift-install create manifests --dir "${OKD_INSTALL_DIR}"

# Set mastersSchedulable parameter in manifests/cluster-scheduler-02-config.yml to false to prevent pods from being scheduled on the control plane machines
yq -i '.spec.mastersSchedulable = false' "${OKD_INSTALL_DIR}/manifests/cluster-scheduler-02-config.yml"

echo -e "${GREEN}5. Create Ignition config files${RESET}"
./openshift-install create ignition-configs --dir "${OKD_INSTALL_DIR}"

echo -e "${GREEN}6. Install FCOS${RESET}"

# Using iso image
./openshift-install coreos print-stream-json | grep '\.iso[^.]'
COREOS_LOCATION=$(./openshift-install coreos print-stream-json | grep '\.iso[^.]' | grep x86_64 | awk '{print $2}' | sed 's/\"//g')
COREOS_LOCATION=$(echo "${COREOS_LOCATION}" | sed 's/,$//')

# Create iso with ssh ignition embedded

curl -L -o coreos.iso "${COREOS_LOCATION}"

podman machine start podman-machine-default

podman run --rm -v "$(pwd)":/data quay.io/coreos/coreos-installer:release \
    iso ignition embed -i /data/coreos-ssh.ign /data/coreos.iso

podman machine stop podman-machine-default

# copy files to web server running in k8s cluster
KUBECONFIG="${WEBSERVER_K8S_KUBECONFIG}"
export KUBECONFIG

WEBSERVER_POD=$(kubectl get pod -n webserver -l app=webserver -o jsonpath="{.items[0].metadata.name}")
WEBSERVER_FILE_PATH="/usr/local/apache2/htdocs"

if [[ -z "${WEBSERVER_POD}" ]]; then
    echo -e "${RED}Error: Web server pod not found. Exiting.${RESET}"
    exit 1
fi

chmod 0644 bootstrap.ign
chmod 0644 master.ign
chmod 0644 worker.ign
echo "Copying ignition files to the web server pod..."
kubectl cp bootstrap.ign ${WEBSERVER_POD}:${WEBSERVER_FILE_PATH} -n webserver --request-timeout=50s
kubectl cp master.ign ${WEBSERVER_POD}:${WEBSERVER_FILE_PATH} -n webserver --request-timeout=50s
kubectl cp worker.ign ${WEBSERVER_POD}:${WEBSERVER_FILE_PATH} -n webserver --request-timeout=50s

sha512sum bootstrap.ign > bootstrap.ign.sha512
sha512sum master.ign > master.ign.sha512
sha512sum worker.ign > worker.ign.sha512

# # Using PXE boot
# PXE_URLS=$(./openshift-install coreos print-stream-json | grep -Eo '"https.*(kernel-|initramfs.|rootfs.)\w+(\.img)?"' | tr -d '"')
# KERNEL_URL=$(echo "${PXE_URLS}" | grep 'x86_64' | grep 'kernel')
# INITRAMFS_URL=$(echo "${PXE_URLS}" | grep 'x86_64' | grep 'initramfs')
# ROOTFS_URL=$(echo "${PXE_URLS}" | grep 'x86_64' | grep 'rootfs')
# echo "Downloading/uploading kernel, initramfs, and rootfs images to the web server pod..."
# kubectl exec -it "${WEBSERVER_POD}" -n webserver -- sh -c "cd ${WEBSERVER_FILE_PATH} && \
#     curl -o kernel.img '${KERNEL_URL}' && \
#     curl -o initramfs.img '${INITRAMFS_URL}' && \
#     curl -o rootfs.img '${ROOTFS_URL}' && \
#     chmod 0644 kernel.img initramfs.img rootfs.img"

scp -i "${PHY_SSH_KEY}" coreos.iso "root@${PHY_BOX_1}":/var/lib/libvirt/images/coreos.iso
scp -i "${PHY_SSH_KEY}" coreos.iso "root@${PHY_BOX_2}":/var/lib/libvirt/images/coreos.iso
scp -i "${PHY_SSH_KEY}" coreos.iso "root@${PHY_BOX_3}":/var/lib/libvirt/images/coreos.iso

cd vms

chmod +x create-bootstrap.sh
chmod +x create-control-plane.sh
chmod +x create-worker.sh

scp -i "${PHY_SSH_KEY}" create-bootstrap.sh "root@${PHY_BOX_1}":create-bootstrap.sh
scp -i "${PHY_SSH_KEY}" create-control-plane.sh "root@${PHY_BOX_1}":create-control-plane.sh
scp -i "${PHY_SSH_KEY}" create-worker.sh "root@${PHY_BOX_1}":create-worker.sh

scp -i "${PHY_SSH_KEY}" create-control-plane.sh "root@${PHY_BOX_2}":create-control-plane.sh
scp -i "${PHY_SSH_KEY}" create-worker.sh "root@${PHY_BOX_2}":create-worker.sh

scp -i "${PHY_SSH_KEY}" create-control-plane.sh "root@${PHY_BOX_3}":create-control-plane.sh
scp -i "${PHY_SSH_KEY}" create-worker.sh "root@${PHY_BOX_3}":create-worker.sh

echo -e "${GREEN}7. Create VMs${RESET}"
ssh -i "${PHY_SSH_KEY}" "root@${PHY_BOX_1}" "./create-bootstrap.sh"
ssh -i "${PHY_SSH_KEY}" "root@${PHY_BOX_1}" "./create-control-plane.sh 1"
ssh -i "${PHY_SSH_KEY}" "root@${PHY_BOX_2}" "./create-control-plane.sh 2"
ssh -i "${PHY_SSH_KEY}" "root@${PHY_BOX_3}" "./create-control-plane.sh 3"

ssh -i "${PHY_SSH_KEY}" "root@${PHY_BOX_1}" "./create-worker.sh 1"
ssh -i "${PHY_SSH_KEY}" "root@${PHY_BOX_2}" "./create-worker.sh 2"
ssh -i "${PHY_SSH_KEY}" "root@${PHY_BOX_3}" "./create-worker.sh 3"

BOOTSTRAP_MAC=$(ssh -i "${PHY_SSH_KEY}" "root@${PHY_BOX_1}" "virsh domiflist bootstrap | awk '{ print \$5 }' | tail -2 | head -1")
CP_1_MAC=$(ssh -i "${PHY_SSH_KEY}" "root@${PHY_BOX_1}" "virsh domiflist cp-1 | awk '{ print \$5 }' | tail -2 | head -1")
CP_2_MAC=$(ssh -i "${PHY_SSH_KEY}" "root@${PHY_BOX_2}" "virsh domiflist cp-2 | awk '{ print \$5 }' | tail -2 | head -1")
CP_3_MAC=$(ssh -i "${PHY_SSH_KEY}" "root@${PHY_BOX_3}" "virsh domiflist cp-3 | awk '{ print \$5 }' | tail -2 | head -1")
WORKER_1_MAC=$(ssh -i "${PHY_SSH_KEY}" "root@${PHY_BOX_1}" "virsh domiflist worker-1 | awk '{ print \$5 }' | tail -2 | head -1")
WORKER_2_MAC=$(ssh -i "${PHY_SSH_KEY}" "root@${PHY_BOX_2}" "virsh domiflist worker-2 | awk '{ print \$5 }' | tail -2 | head -1")
WORKER_3_MAC=$(ssh -i "${PHY_SSH_KEY}" "root@${PHY_BOX_3}" "virsh domiflist worker-3 | awk '{ print \$5 }' | tail -2 | head -1")

echo -e "${GREEN}8. Print node MAC addresses and get IPs ${RESET}"

read -p "Enter the bootstrap IP with MAC ${BOOTSTRAP_MAC}: " BOOTSTRAP_IP
read -p "Enter the cp-1 IP with MAC ${CP_1_MAC}: " CP_1_IP
read -p "Enter the cp-2 IP with MAC ${CP_2_MAC}: " CP_2_IP
read -p "Enter the cp-3 IP with MAC ${CP_3_MAC}: " CP_3_IP
read -p "Enter the worker-1 IP with MAC ${WORKER_1_MAC}: " WORKER_1_IP
read -p "Enter the worker-2 IP with MAC ${WORKER_2_MAC}: " WORKER_2_IP
read -p "Enter the worker-3 IP with MAC ${WORKER_3_MAC}: " WORKER_3_IP
# read -p "Acknowledge and enter new IPs into DNS: " YES

ssh-keygen -R "${BOOTSTRAP_IP}"
ssh-keygen -R "${CP_1_IP}"
ssh-keygen -R "${CP_2_IP}"
ssh-keygen -R "${CP_3_IP}"
ssh-keygen -R "${WORKER_1_IP}"
ssh-keygen -R "${WORKER_2_IP}"
ssh-keygen -R "${WORKER_3_IP}"

sleep 10

echo -e "${GREEN}9. Apply custom ignition and reboot to start OKD install ${RESET}"

BOOTSTRAP_SHA=$(cat bootstrap.ign.sha512 | awk '{print $1}')
MASTER_SHA=$(cat master.ign.sha512 | awk '{print $1}')
WORKER_SHA=$(cat worker.ign.sha512 | awk '{print $1}')

ssh -i "${CORE_SSH_KEY}" "core@${BOOTSTRAP_IP}" "sudo coreos-installer install --ignition-url=${WEBSERVER_PATH}/bootstrap.ign /dev/vda --ignition-hash=sha512-${BOOTSTRAP_SHA}"
ssh -i "${CORE_SSH_KEY}" "core@${CP_1_IP}" "sudo coreos-installer install --ignition-url=${WEBSERVER_PATH}/master.ign /dev/vda --ignition-hash=sha512-${MASTER_SHA}"
ssh -i "${CORE_SSH_KEY}" "core@${CP_2_IP}" "sudo coreos-installer install --ignition-url=${WEBSERVER_PATH}/master.ign /dev/vda --ignition-hash=sha512-${MASTER_SHA}"
ssh -i "${CORE_SSH_KEY}" "core@${CP_3_IP}" "sudo coreos-installer install --ignition-url=${WEBSERVER_PATH}/master.ign /dev/vda --ignition-hash=sha512-${MASTER_SHA}"
ssh -i "${CORE_SSH_KEY}" "core@${WORKER_1_IP}" "sudo coreos-installer install --ignition-url=${WEBSERVER_PATH}/worker.ign /dev/vda --ignition-hash=sha512-${WORKER_SHA}"
ssh -i "${CORE_SSH_KEY}" "core@${WORKER_2_IP}" "sudo coreos-installer install --ignition-url=${WEBSERVER_PATH}/worker.ign /dev/vda --ignition-hash=sha512-${WORKER_SHA}"
ssh -i "${CORE_SSH_KEY}" "core@${WORKER_3_IP}" "sudo coreos-installer install --ignition-url=${WEBSERVER_PATH}/worker.ign /dev/vda --ignition-hash=sha512-${WORKER_SHA}"

sleep 10

ssh -i "${PHY_SSH_KEY}" "root@${PHY_BOX_1}" "virsh shutdown bootstrap; virsh shutdown cp-1; virsh shutdown worker-1; sleep 10; virsh start bootstrap; virsh start cp-1; virsh start worker-1"
ssh -i "${PHY_SSH_KEY}" "root@${PHY_BOX_2}" "virsh shutdown cp-2; virsh shutdown worker-2; sleep 10; virsh start cp-2; virsh start worker-2"
ssh -i "${PHY_SSH_KEY}" "root@${PHY_BOX_3}" "virsh shutdown cp-3; virsh shutdown worker-3; sleep 10; virsh start cp-3; virsh start worker-3"

echo -e "${GREEN}10. Wait for bootstrap to complete${RESET}"
cd "${OKD_INSTALL_DIR}"
./openshift-install --dir "${OKD_INSTALL_DIR}" wait-for bootstrap-complete --log-level=info

# restart haproxy service
# systemctl restart haproxy.service
# remove bootstrap machine from load balancer

# approve csrs
# oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs oc adm certificate approve

# ./openshift-install --dir "${OKD_INSTALL_DIR}" wait-for install-complete 
