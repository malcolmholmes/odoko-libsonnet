local k = import 'ksonnet-util/kausal.libsonnet';

{
  withApacheConfig(name, config):: {
    local configMap = k.core.v1.configMap,

    ['configmap-' + name]: configMap.new(name)
                           + configMap.withData({ name: config })
    ,
    statefulset+: k.util.configVolumeMount(name, '/etc/apache2/sites-enabled/%s.conf' % name),
  },
}
