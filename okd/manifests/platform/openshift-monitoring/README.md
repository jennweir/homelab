# openshift-monitoring

Configure alertmanager discord receiver

## Update alertmanager config

```bash
kubectl get secret alertmanager-discord-config -o jsonpath="{.data.alertmanager-discord-config}" | base64 -d > alertmanager.yaml

oc -n openshift-monitoring create secret generic alertmanager-main --from-file=alertmanager.yaml --dry-run=client -o=yaml |  oc -n openshift-monitoring replace secret --filename=-

rm alertmanager.yaml
```

## Template for alertmanager external secret

```yaml
"global":
  "http_config":
    "proxy_from_environment": true
"inhibit_rules":
  - "equal":
      - "namespace"
      - "alertname"
    "source_matchers":
      - "severity = critical"
    "target_matchers":
      - "severity =~ warning|info"
  - "equal":
      - "namespace"
      - "alertname"
    "source_matchers":
      - "severity = warning"
    "target_matchers":
      - "severity = info"
"receivers":
  - "name": "Default"
    discord_configs:
      - webhook_url: >-
          <DEFAULT_WEBHOOK_URL>
        message: |-
          {{ range .Alerts.Firing }}
              Alert: **{{ printf "%.150s" .Annotations.summary }}** ({{ .Labels.severity }})
              Description: {{ printf "%.150s" .Annotations.description }}
              Alertname: {{ .Labels.alertname }}
              Namespace: {{ .Labels.namespace }}
              Service: {{ .Labels.service }}
          {{ end }}

          {{ range .Alerts.Resolved }}
              Alert: **{{ printf "%.150s" .Annotations.summary }}** ({{ .Labels.severity }})
              Description: {{ printf "%.150s" .Annotations.description }}
              Alertname: {{ .Labels.alertname }}
              Namespace: {{ .Labels.namespace }}
              Service: {{ .Labels.service }}
          {{ end }}
  - "name": "Watchdog"
    discord_configs:
      - webhook_url: >-
          <WATCHDOG_WEBHOOK_URL>
        message: |-
          {{ range .Alerts.Firing }}
              Alert: **{{ printf "%.150s" .Annotations.summary }}** ({{ .Labels.severity }})
              Description: {{ printf "%.150s" .Annotations.description }}
              Alertname: {{ .Labels.alertname }}
              Namespace: {{ .Labels.namespace }}
              Service: {{ .Labels.service }}
          {{ end }}

          {{ range .Alerts.Resolved }}
              Alert: **{{ printf "%.150s" .Annotations.summary }}** ({{ .Labels.severity }})
              Description: {{ printf "%.150s" .Annotations.description }}
              Alertname: {{ .Labels.alertname }}
              Namespace: {{ .Labels.namespace }}
              Service: {{ .Labels.service }}
          {{ end }}
  - "name": "Critical"
    discord_configs:
      - webhook_url: >-
          <CRITICAL_WEBHOOK_URL>
        message: |-
          {{ range .Alerts.Firing }}
              Alert: **{{ printf "%.150s" .Annotations.summary }}** ({{ .Labels.severity }})
              Description: {{ printf "%.150s" .Annotations.description }}
              Alertname: {{ .Labels.alertname }}
              Namespace: {{ .Labels.namespace }}
              Service: {{ .Labels.service }}
          {{ end }}

          {{ range .Alerts.Resolved }}
              Alert: **{{ printf "%.150s" .Annotations.summary }}** ({{ .Labels.severity }})
              Description: {{ printf "%.150s" .Annotations.description }}
              Alertname: {{ .Labels.alertname }}
              Namespace: {{ .Labels.namespace }}
              Service: {{ .Labels.service }}
          {{ end }}
"route":
  "group_by":
    - "namespace"
  "group_interval": "5m"
  "group_wait": "30s"
  "receiver": "Default"
  "repeat_interval": "12h"
  "routes":
    - "matchers":
        - "alertname = Watchdog"
      "receiver": "Watchdog"
    - "matchers":
        - "severity = critical"
      "receiver": "Critical"
```

## References

<https://codeaffen.org/2023/12/28/discord_as_alertmanager_receiver/>
