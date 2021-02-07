local k = import 'ksonnet-util/kausal.libsonnet';

{
  local volume = k.core.v1.volume,
  local mount = k.core.v1.volumeMount,
  local statefulset = k.apps.v1.statefulSet,
  local container = k.core.v1.container,

  _images+:: {
    wordpress: 'odoko/wordpress:5.6.0',
    wordpress_latest: 'odoko/wordpress:latest',
  },

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
      wordpress_image: $._images.wordpress,
      uploads_size: '1Gi',
      plugins: (import 'default-plugins.libsonnet'),
    },

    local config = self.config,

    local plugins = {
      plugins: [config.plugins.plugins[plugin] for plugin in std.objectFields(config.plugins.plugins)],
      current_theme: config.plugins.current_theme,
      themes: [config.plugins.themes[theme] for theme in std.objectFields(config.plugins.themes)],
    },

    config_map: configMap.new('wordpress-config')
                + configMap.withData({
                  'php-ini': importstr 'files/php.ini',
                  'plugins.json': std.manifestJsonEx(std.prune(plugins), '  '),
                })
    ,

    pvc: pvc.new()
         + pvc.metadata.withName('uploads')
         + pvc.spec.resources.withRequests({ storage: config.uploads_size })
         + pvc.spec.withAccessModes(['ReadWriteMany'])
         + pvc.spec.withStorageClassName('csi-cephfs')
         + { apiVersion: 'v1', kind: 'PersistentVolumeClaim' },

    local volumes = [
      volume.fromConfigMap(name='wordpress-config', configMapName='wordpress-config'),
      volume.fromSecret('gcs-auth', 'gcs-auth'),
      volume.fromPersistentVolumeClaim('uploads', 'uploads'),
    ],

    local volumeMounts = [
      mount.new('wordpress-config', '/usr/local/etc/php/conf.d/php.ini') + mount.withSubPath('php.ini'),
      mount.new('wordpress-config', '/plugins/plugins.json') + mount.withSubPath('plugins.json'),
      mount.new('gcs-auth', '/var/run/secrets/gcs-auth', true),
      mount.new('uploads', '/var/www/html/wp-content/uploads'),
    ],

    _container:: container.new(name, self.config.wordpress_image)
                 + container.withPorts(containerPort.newNamed(containerPort=port, name='http-metrics'))
                 + container.withImagePullPolicy('Always')
                 + container.withVolumeMounts(volumeMounts)
                 + container.withEnvMap({
                   CMD: 'wordpress',
                   PLUGINS_FILE: '/plugins/plugins.json',
                   WORDPRESS_DB_HOST: 'mysql.mysql',
                   WORDPRESS_DB_USER: name,
                   WORDPRESS_DB_PASSWORD: 'wordpress',
                   WORDPRESS_DB_NAME: name,
                   WP_DEBUG: 'true',
                 }),

    local _initContainer = container.new(name + '-init', 'busybox')
                           + container.withVolumeMounts(volumeMounts)
                           + container.withCommand(['sh', '-c', 'chown -R www-data:www-data /var/www/html/wp-content/uploads']),

    local labels = { app: name },

    service: service.new(name, labels, servicePort.new(port, port))
             + service.spec.withType('NodePort')
             + service.spec.withExternalTrafficPolicy('Local')
    ,

    statefulset: statefulset.new('wordpress', 1, [self._container], [], labels)
                 + statefulset.spec.template.spec.withVolumes(volumes)
                 + statefulset.spec.template.spec.withInitContainers([_initContainer])
                 + statefulset.spec.withServiceName(name),
  },

  withReplicas(replicas):: {
    statefulset+: statefulset.mixin.spec.withReplicas(replicas),
  },

  withPlugins(plugins):: {
    config+:: {
      plugins+:: plugins,
    },
  },

  withTheme(name, theme):: {
    config+:: {
      plugins+: {
        current_theme: name,
        themes: {
          [name]+: {
            name: name,
            url: theme,
          },
        },
      },
    },
  },

  withNodeSelector(selector):: {
    statefulset+: statefulset.mixin.spec.template.spec.withNodeSelector(selector),
  },

  withImagePullSecret(secret):: {
    local imagePullSecrets = statefulset.mixin.spec.template.spec.imagePullSecretsType,
    statefulset+: statefulset.mixin.spec.template.spec.withImagePullSecrets(
      imagePullSecrets.new() +
      imagePullSecrets.withName(secret)
    ),
  },
}
