local k = import 'k.libsonnet';
local kausal = import 'ksonnet-util/kausal.libsonnet';
{
  local statefulset = k.apps.v1.statefulSet,
  local container = k.core.v1.container,
  local containerPort = container.portsType,
  local service = k.core.v1.service,
  local volume = k.core.v1.volume,
  local pvc = k.core.v1.persistentVolumeClaim,
  local pv = k.core.v1.persistentVolume,
  local mount = k.core.v1.volumeMount,

  _images+:: {
    mysql: 'mysql:5.7',
  },

  withPVC(size)::
    {
      local _containers = super.statefulset.spec.template.spec.containers,
      statefulset+: {
        spec+: {
          volumeClaimTemplates::: statefulset.mixin.spec.withVolumeClaimTemplatesMixin(
            pvc.new('mysql')
            + pvc.mixin.spec.resources.withRequests({ storage: size })
            + pvc.mixin.spec.withAccessModes(['ReadWriteOnce'])
            + pvc.mixin.metadata.withName('database')
          ).spec.volumeClaimTemplates,
          template+: {
            spec+: {
              containers: [
                _container { volumeMounts+: [mount.new('database', '/var/lib/mysql')] }
                for _container in _containers
              ],
            },
          },
        },
      },
    }
  ,
  new(name, dbName, username, password, rootPassword, port=3306):: {
    name:: name,

    local _container = container.new(name, $._images.mysql)
                       + container.withPorts(containerPort.newNamed(port, 'mysql'))
                       + container.withArgs(['--verbose', '--ignore-db-dir', 'lost+found'])
                       + container.withEnvMap({
                         MYSQL_ROOT_PASSWORD: rootPassword,
                         MYSQL_DATABASE: dbName,
                         MYSQL_USER: username,
                         MYSQL_PASSWORD: password,
                       })
    ,

    local labels = { app: name },

    statefulset: statefulset.new(name, 1, _container, [], labels)
                 + statefulset.mixin.spec.withServiceName('mysql'),

    service: kausal.util.serviceFor(self.statefulset),
  },

  withHostVolume(path):: {
    statefulset+: kausal.util.hostVolumeMount(super.name, path, '/var/lib/mysql'),
  },

  withNodeSelector(selector):: {
    statefulset+: statefulset.mixin.spec.template.spec.withNodeSelector(selector),
  },
}
