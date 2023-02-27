grafana:
  enabled: enable
  adminPassword: admin
  serviceAccount:
    create: false
    name: grafana-sa
    annotations: 
      eks.amazonaws.com/role-arn: ${grafana_iam}
  grafana.ini:
    auth:
      sigv4_auth_enabled: true
  additionalDataSources:
    - name: Amazon Managed Prometheus
      type: prometheus
      access: proxy
      url: ${url}
      isDefault: false
      jsonData:
        timeInterval: 15s
        sigV4Auth: true
        sigV4Region: ${region}
        sigV4AuthType: default
  sidecar:
    datasources:
      defaultDatasourceEnabled: true
  ingress:
    enabled: true
    annotations:
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}]'
      alb.ingress.kubernetes.io/success-codes: 200-302
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/target-type: ip
      kubernetes.io/ingress.class: alb
    path: /*
    pathType: ImplementationSpecific
    
kubeEtcd:
  enabled: false
 
kubeScheduler:
  enabled: false

kubeControllerManager:
  enabled: false

nodeExporter:
  enabled: false

alertmanager:
  enabled: false

prometheus:
  serviceAccount:
    create: false
    name: prometheus-sa
    annotations: 
      eks.amazonaws.com/role-arn: ${prometheus_iam}
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    remoteWrite:
    - url: ${url}api/v1/remote_write
      sigv4:
        region: ${region}