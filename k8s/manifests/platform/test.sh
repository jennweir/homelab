#!/usr/bin/env bash
# platform-level exemptions for infra resources that are shipped
# deviating from pod security best practices
export EXEMPTIONS=(
  "check=podspec-defaults,kind=Pod,name=kube-vip"
  "check=podspec-defaults,kind=DaemonSet,name=kube-flannel-ds"
)
