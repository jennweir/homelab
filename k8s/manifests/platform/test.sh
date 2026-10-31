#!/usr/bin/env bash
# Platform-level exemptions for infra resources that legitimately
# deviate from pod security best practices (hostNetwork, privileged
# containers, etc.) required for their function.
EXEMPTIONS=(
  check=podspec-defaults,kind=Pod,name=kube-vip
  check=podspec-defaults,kind=DaemonSet,name=kube-flannel-ds
)
