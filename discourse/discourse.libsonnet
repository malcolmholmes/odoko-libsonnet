local helm = (import 'github.com/grafana/jsonnet-libs/helm-util/helm.libsonnet').new(std.thisFile);
local k = import 'ksonnet-util/kausal.libsonnet';

{
  values:: {
    ingress: {
      enabled: true,
      certManager: true,
      hostname: $._config.hostname,
      tls: true,
      annotations: {
        'kubernetes.io/ingress.class': 'nginx',
        'odoko.com/dyn-dns-zone': $._config.zone,
      },
    },
    service: {
      type: 'ClusterIP',
    },
    discourse: {
      host: error 'host name required',
      siteName: error 'siteName required',
      username: error 'default username required',
      email: error 'site email address required',
      extraEnvVarsCM: 'discourse-smtp',
    },
    sidekiq: {
      extraEnvVarsCM: 'discourse-smtp',
    },
    image: {
      debug: true,
    },
  },

  namespace: k.core.v1.namespace.new($._config.namespace),

  local configMap = k.core.v1.configMap,

  configmap: configMap.new('discourse-smtp')
             + configMap.withData({
               SMTP_HOST: $._config.smtp.host,
               SMTP_PORT: $._config.smtp.port,
               SMTP_USER: $._config.smtp.user,
               SMTP_PASSWORD: $._config.smtp.pass,
               SMTP_TLS: 'yes',
             }),

  discourse: helm.template('discourse', './charts/discourse', {
    values: $.values,
    namespace: $._config.namespace,
  }),

  withBackupMount(pvcName):: {
    local pvc = k.core.v1.persistentVolumeClaim,
    backup_pvc: pvc.new(pvcName)
                + pvc.spec.resources.withRequests({ storage: '1Gi' })
                + pvc.spec.withAccessModes(['ReadWriteMany'])
                + pvc.spec.withStorageClassName('csi-cephfs')
    ,

    discourse+: {
      deployment_discourse+: k.util.pvcVolumeMount(pvcName, '/opt/bitnami/discourse-sidekiq/public/backups/default'),
    },
  },
}
