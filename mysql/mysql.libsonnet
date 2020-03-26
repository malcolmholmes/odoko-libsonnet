local k = import 'ksonnet-util/kausal.libsonnet';
{
  local statefulset = k.apps.v1.statefulSet,
  local container = k.core.v1.container,
  local containerPort = container.portsType,
  local service = k.core.v1.service,
  local servicePort = k.core.v1.service.mixin.spec.portsType,
  local volume = k.core.v1.volume,
  local pvc = k.core.v1.persistentVolumeClaim,
  local pv = k.core.v1.persistentVolume,
  local mount = k.core.v1.volumeMount,

  _images+:: {
      mysql: "mysql:5.7",
  },

  withPV(size):: {
    pv: pv.new()
    + pv.mixin.metadata.withName('database')
    + pv.mixin.spec.withStorageClassName('storage')
    + pv.mixin.spec.hostPath.withPath('/data/db')
    + pv.mixin.spec.withAccessModes(['ReadWriteOnce'])
	+ pv.mixin.spec.withCapacity({storage: size })
  },

  withPVC(size):: 
    {
      local _containers = super.statefulset.spec.template.spec.containers,
      statefulset+: {
        spec+: {
          volumeClaimTemplates::: statefulset.mixin.spec.withVolumeClaimTemplatesMixin(
            pvc.new()
            + pvc.mixin.spec.resources.withRequests({ storage: size })
            + pvc.mixin.spec.withAccessModes(['ReadWriteOnce'])
            + pvc.mixin.spec.withStorageClassName('storage')
            + pvc.mixin.metadata.withName('database')
          ).spec.volumeClaimTemplates,
          template+: {
            spec+: {
              containers: [
                _container + {volumeMounts+:[mount.new('database', '/var/lib/mysql')]}
                for _container in _containers
              ],
            },
          },
        },
     }
   }
  ,
  new(name, dbName, username, password, rootPassword, port=3306):: {
    local _container = container.new(name, $._images.mysql)
          .withPorts(containerPort.new(port))
          .withArgs(["--verbose", "--ignore-db-dir", "lost+found"])
        .withEnvMap({
          MYSQL_ROOT_PASSWORD: rootPassword,
          MYSQL_DATABASE: dbName,
          MYSQL_USER: username,
          MYSQL_PASSWORD: password 
        })
    ,

    local labels = {app: name},

    service: service.new(name, labels, servicePort.new(port, port))
       .withClusterIp('None'),

    statefulset: statefulset.new(name, 1, _container, [], labels)
      .withServiceName(name)
    ,
  },

  withNodeSelector(selector):: {
    statefulset+:  statefulset.mixin.spec.template.spec.withNodeSelector(selector)
  },
}
