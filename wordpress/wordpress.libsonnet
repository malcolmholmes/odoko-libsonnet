local k = import 'ksonnet-util/kausal.libsonnet';

{
  _images+:: {
    wordpress: 'odoko/wordpress',
  },

  local volume = k.core.v1.volume,
  local mount = k.core.v1.volumeMount,
  local statefulset = k.apps.v1.statefulSet,
  local container = k.core.v1.container,

  new(name, domain, db_pass, port=80):: {
    local containerPort = container.portsType,
    local service = k.core.v1.service,
    local servicePort = k.core.v1.service.mixin.spec.portsType,
    local pvc = k.core.v1.persistentVolumeClaim,
    local pv = k.core.v1.persistentVolume,
    local configMap = k.core.v1.configMap,

    config:: {
      name: name,
      domain: domain,
      db_name: name,
      db_user: name,
      db_pass: db_pass,
    },

    config_map: configMap.new('wordpress-config')
      + configMap.withData({'php-ini': importstr 'files/php.ini'})
      + configMap.withData({'plugins.json': importstr 'files/plugins.json'})
      ,
   
    local volumes = [
      volume.fromConfigMap(name='wordpress-config', configMapName='wordpress-config'),
      volume.fromSecret('gcs-auth', 'gcs-auth'),
    ],

    local volumeMounts = [
      mount.new('wordpress-config', '/usr/local/etc/php/conf.d/php.ini').withSubPath('php.ini'),
      mount.new('wordpress-config', '/plugins/plugins.json').withSubPath('plugins.json'),
      mount.new('gcs-auth', 'var/run/secrets/gcs-auth', true),
    ],

    local _container = container.new(name, $._images.wordpress)
      .withPorts(containerPort.new(port))
      .withImagePullPolicy('Always')
      .withVolumeMounts(volumeMounts)
      .withEnvMap({
        CMD: "wordpress",
        PLUGINS_FILE: "/plugins/plugins.json",
        WORDPRESS_DB_HOST: "mysql.mysql",
        WORDPRESS_DB_USER: name,
        WORDPRESS_DB_PASSWORD: "wordpress",
        WORDPRESS_DB_NAME: name,
        WP_DEBUG: "true",
      }),

    local _initContainer = container.new(name + "-init", 'busybox')
      .withVolumeMounts(volumeMounts)
      .withCommand(["sh", "-c", "chown -R www-data:www-data /var/www/html/wp-content/uploads"]),

    local labels = {app: name},

    service: service.new(name, labels, servicePort.new(port, port))
      .withType("ClusterIP")
      ,

    statefulset: statefulset.new('wordpress', 1, [_container], [], labels)
      .withVolumes(volumes)
      .withInitContainers([_initContainer])
      + statefulset.mixin.spec.withServiceName(name)
      ,
  },

  withReplicas(replicas):: {
    statefulset+: statefulset.mixin.spec.withReplicas(replicas),
  },

  withHostPath():: {
    local name = super.config.name,
    local sts = super.statefulset,

    statefulset+: 
      statefulset.mixin.spec.template.spec.withVolumesMixin(volume.fromHostPath('uploads', '/uploads/%s' % name))
      + statefulset.mixin.spec.template.spec.withContainers([
        _container + container.withVolumeMountsMixin(mount.new('uploads', '/var/www/html/wp-content/uploads'))
        for _container in sts.spec.template.spec.containers
      ])
      + statefulset.mixin.spec.template.spec.withInitContainers([
        _container + container.withVolumeMountsMixin(mount.new('uploads', '/var/www/html/wp-content/uploads'))
        for _container in sts.spec.template.spec.initContainers
      ])
      ,
  },
}
