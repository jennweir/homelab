# Cilium

Serving as CNI + Gateway API provider

> Note: Enabling Cilium as a Gateway API provider replaces kube-proxy
> Verify with `kubectl exec -n kube-system ds/cilium -- cilium-dbg status` and look for
> `KubeProxyReplacement:    True   [eno1   192.168.0.13 fe80::cd39:6a26:4892:3c98 (Direct Routing)]`

Ref:

- <https://docs.cilium.io/en/latest/network/servicemesh/gateway-api/gateway-api/>
