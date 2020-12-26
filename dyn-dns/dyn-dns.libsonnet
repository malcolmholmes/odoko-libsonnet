local k = import 'ksonnet-util/kausal.libsonnet';

{
  local container = k.core.v1.container,
  local volume = k.core.v1.volume,
  local mount = k.core.v1.volumeMount,
  local cronjob = k.batch.v1beta1.cronJob,
  local secret = k.core.v1.secret,

  _images+:: {
    admin: 'odoko/admin:latest',
  },

  new(auth, zone, domains):: {
    local dnsAuth = std.base64(std.manifestJsonEx(auth, '  ')),
    dns_auth_secret: secret.new('dns-auth', { key: dnsAuth }, 'Opaque'),

    local _container = container.new('dyndns', $._images.admin)
                     .withImagePullPolicy('Always')
                     .withEnvMap({
                       CMD: 'dyndns',
                       DOMAINS: std.join(' ', domains),
                       ZONENAME: zone,
                     })
    ,

    dyndns_cron: cronjob.new()
       + cronjob.mixin.metadata.withName('dyn-dns-' + zone)
       + cronjob.mixin.spec.withSchedule('*/1 * * * *')
       + cronjob.mixin.spec.withSuccessfulJobsHistoryLimit(1)
       + cronjob.mixin.spec.withFailedJobsHistoryLimit(1)
       + cronjob.mixin.spec.jobTemplate.spec.template.spec.withContainers([_container])
       + cronjob.mixin.spec.jobTemplate.spec.template.spec.withRestartPolicy('OnFailure')
       + {
           spec+: {
             jobTemplate+: k.util.secretVolumeMount('dns-auth', '/var/run/secrets/dns-auth')
           }
         }
       ,
  }
}
