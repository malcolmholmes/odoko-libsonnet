local k = import 'ksonnet-util/kausal.libsonnet';

{
  local volume = k.core.v1.volume,
  local mount = k.core.v1.volumeMount,
  local statefulset = k.apps.v1.statefulSet,
  local container = k.core.v1.container,
  local secret = k.core.v1.secret,

  _images+:: {
    wordpress: 'odoko/wordpress:5.7.1',
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
      content_size: '5Gi',
      plugins: (import 'default-plugins.libsonnet'),
      port_name: 'wordpress',
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

    content_pvc: pvc.new()
                 + pvc.metadata.withName('content')
                 + pvc.spec.resources.withRequests({ storage: config.content_size })
                 + pvc.spec.withAccessModes(['ReadWriteMany'])
                 + pvc.spec.withStorageClassName('csi-cephfs')
                 + { apiVersion: 'v1', kind: 'PersistentVolumeClaim' },

    local volumes = [
      volume.fromConfigMap(name='wordpress-config', configMapName='wordpress-config'),
      volume.fromPersistentVolumeClaim('content', 'content'),
      //      volume.fromPersistentVolumeClaim('uploads', 'uploads'),
    ],

    local volumeMounts = [
      mount.new('wordpress-config', '/usr/local/etc/php/conf.d/php.ini') + mount.withSubPath('php.ini'),
      mount.new('wordpress-config', '/plugins/plugins.json') + mount.withSubPath('plugins.json'),
      mount.new('content', '/var/www/html/wp-content'),
    ],

    _container:: container.new(name, self.config.wordpress_image)
                 + container.withPorts(containerPort.newNamed(containerPort=port, name=config.port_name))
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
                 })
                 + container.mixin.livenessProbe.httpGet.withPath('/healthcheck')
                 + container.mixin.livenessProbe.httpGet.withPort(config.port_name)
                 + container.mixin.livenessProbe.withInitialDelaySeconds(5)
                 + container.mixin.startupProbe.httpGet.withPath('/healthcheck')
                 + container.mixin.startupProbe.httpGet.withPort(config.port_name)
                 + container.mixin.startupProbe.withInitialDelaySeconds(5)
                 + container.mixin.startupProbe.withPeriodSeconds(10)
                 + container.mixin.startupProbe.withFailureThreshold(30)
    ,

    local _initContainer = container.new(name + '-init', 'busybox')
                           + container.withVolumeMounts(volumeMounts)
                           + container.withCommand(['sh', '-c', 'mkdir -p /var/www/html/wp-content/uploads && chown -R www-data:www-data /var/www/html/wp-content/uploads']),

    local labels = { app: name },

    service: service.new(name, labels, servicePort.new(port, port))
             + service.spec.withType('NodePort')
             + service.spec.withExternalTrafficPolicy('Local')
    ,

    statefulset: statefulset.new('wordpress', 1, [self._container], [], labels)
                 + statefulset.spec.template.spec.withVolumes(volumes)
                 + statefulset.spec.template.spec.withInitContainers([_initContainer])
                 + statefulset.spec.withServiceName(name)
                 + k.util.secretVolumeMount('gcs-auth', '/var/run/secrets/gcs-auth'),
  },

  withReplicas(replicas):: {
    statefulset+: statefulset.mixin.spec.withReplicas(replicas),
  },

  withPlugins(plugins):: {
    config+:: {
      plugins+:: plugins,
    },
  },

  withGoogleSecret(creds):: {
    gcs_auth_secret: secret.new('gcs-auth', { key: std.base64(std.manifestJsonEx(creds, '')) }, 'Opaque'),
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
