local k = import 'ksonnet-util/kausal.libsonnet';

{
  local container = k.core.v1.container,
  local cronjob = k.batch.v1beta1.cronJob,
  local job = k.batch.v1.job,
  local secret = k.core.v1.secret,
  local volume = k.core.v1.volume,
  local mount = k.core.v1.volumeMount,

  local volume_mounts = [
    mount.new('uploads', '/uploads'),
    mount.new('gcs-auth', 'var/run/secrets/gcs-auth', true),
  ],

  local volumes(site) = [
    volume.fromPersistentVolumeClaim('uploads', 'uploads'),
    volume.fromSecret('gcs-auth', 'gcs-auth'),
  ],

  withGoogleSecret(creds):: {
    gcs_auth_secret: secret.new('gcs-auth', { key: std.base64(std.manifestJsonEx(creds, '')) }, 'Opaque'),
  },

  local _container(config, command, bucket) = container.new(config.name + '-backup', $._images.wordpress)
                                              + container.withImagePullPolicy('Always')
                                              + container.withEnvMap({
                                                CMD: command,
                                                BUCKET: bucket,
                                                WORDPRESS_DB_NAME: config.db_name,
                                                WORDPRESS_DB_USER: config.db_user,
                                                WORDPRESS_DB_PASSWORD: config.db_pass,
                                              })
                                              + container.withVolumeMounts(volume_mounts)
  ,
  withBackupJob(bucket):: {

    local backup_container = _container(super.config, 'backup', bucket),

    backup_cron: cronjob.new()
                 + cronjob.mixin.metadata.withName('%s-backup' % super.config.name)
                 + cronjob.mixin.spec.withSchedule('0 0 * * *')
                 + cronjob.mixin.spec.withSuccessfulJobsHistoryLimit(1)
                 + cronjob.mixin.spec.withFailedJobsHistoryLimit(1)
                 + cronjob.mixin.spec.jobTemplate.spec.template.spec.withContainers([backup_container])
                 + cronjob.mixin.spec.jobTemplate.spec.template.spec.withRestartPolicy('OnFailure')
                 + cronjob.mixin.spec.jobTemplate.spec.template.spec.withVolumes(volumes(super.config.name)),
  }
  ,

  withRestoreJob(bucket): {

    local restore_container = _container(super.config, 'restore', bucket),

    restore_job: cronjob.new()
                 + cronjob.mixin.metadata.withName('%s-restore' % super.config.name)
                 + cronjob.mixin.spec.withSchedule('0 0 31 2 *')  // i.e. never. will be run manually
                 + cronjob.mixin.spec.withSuccessfulJobsHistoryLimit(1)
                 + cronjob.mixin.spec.withFailedJobsHistoryLimit(1)
                 + cronjob.mixin.spec.jobTemplate.spec.template.spec.withContainers([restore_container])
                 + cronjob.mixin.spec.jobTemplate.spec.template.spec.withRestartPolicy('Never')
                 + cronjob.mixin.spec.jobTemplate.spec.template.spec.withVolumes(volumes(super.config.name)),
  },
}
