{{- define "envoy.clusterEndpoint" -}}
- name: {{ .name }}
  connect_timeout: 5s
  type: strict_dns
  lb_policy: round_robin
  load_assignment:
    cluster_name: {{ .name }}
    endpoints:
      - lb_endpoints:
          - endpoint:
              address:
                socket_address:
                  address: {{ .address }}
                  port_value: {{ .port }}
{{- if eq .protocol "http2" }}
  http2_protocol_options: {}
{{- end }}
{{- end }}
