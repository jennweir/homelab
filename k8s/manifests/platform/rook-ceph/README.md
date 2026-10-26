# Ceph Installation

## Ceph notes

- `ceph osd pool application enable .mgr mgr`
- If storage device backing osd is up but ceph is reporting that osd as down, bouncing the rook-ceph-osd pod for that osd will make ceph recognize it is back up
- Use ceph tools pod to check health and clear warnings
  - `kubectl exec -it -n rook-ceph deploy/rook-ceph-tools -- ceph status`
  - `kubectl exec -it -n rook-ceph deploy/rook-ceph-tools -- ceph osd tree`
  - `kubectl exec -it -n rook-ceph deploy/rook-ceph-tools -- ceph crash ls`
  - `kubectl exec -it -n rook-ceph deploy/rook-ceph-tools -- ceph crash info <ID>`
  - `kubectl exec -it -n rook-ceph deploy/rook-ceph-tools -- ceph crash archive <ID>`
  - `kubectl exec -it -n rook-ceph deploy/rook-ceph-tools -- ceph df`

## Clean up storage drives to redeploy ceph cluster

Per node

```bash
sudo rm -rf /var/lib/rook/*
sudo sgdisk --zap-all /dev/sdX
sudo blkdiscard /dev/sdX
```
