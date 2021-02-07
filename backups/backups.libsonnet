local k = import 'ksonnet-util/kausal.libsonnet';

{
  local container = k.core.v1.container,
  local cronjob = k.batch.v1beta1.cronJob,
  local job = k.batch.v1.job,
  local secret = k.core.v1.secret,
  local volume = k.core.v1.volume,
  local mount = k.core.v1.volumeMount,

  _images+: {
    backups: 'odoko/backup',
  },

  withGoogleSecret(creds):: {
    gcs_auth_secret: secret.new('gcs-auth', { key: std.base64(std.manifestJsonEx(creds, '')) }, 'Opaque'),
  },

  local _container(env, creds, mounts, domain=null, replace=null, from=null, newerThanSeconds='')
  = container.new(env.DB_NAME + '-backup', $._images.backups)
    + container.withImagePullPolicy('Always')
    + container.withEnvMap(
      env
      {
        SERVICE_ACCOUNT: creds.client_email,
        SERVICE_ACCOUNT_KEY: '/var/run/secrets/gcs-auth/key',
        GOOGLE_APPLICATION_CREDENTIALS: '/var/run/secrets/gcs-auth/key',
        GOOGLE_PROJECT: creds.project_id,
      }
      + (if from == null then {} else { FROM_ENV: from })
      + (if domain == null then {} else { DOMAIN: domain })
      + (if replace == null then {} else { REPLACE: replace })
      ,
    )
    + container.withVolumeMounts(mounts)
  ,

  newBackupJob(db_name, db_pass, bucket, creds, path='/uploads', job_name='backup-db'):: {

    uploadsTasks:: ',backup-uploads,prune-uploads',
    local uploadsTasks = self.uploadsTasks,
    env:: {
      CMD: job_name + ',prune-db' + uploadsTasks,
      BUCKET: bucket,
      DB_NAME: db_name,
      DB_HOST: 'mysql.mysql',
      DB_PASS: db_pass,
      DB_USER: db_name,
    },
    uploadsMount:: [mount.new('uploads', '/uploads')],
    uploadsVolume:: [volume.fromPersistentVolumeClaim('uploads', 'uploads')],
    mounts:: [mount.new('gcs-auth', '/var/run/secrets/gcs-auth', true)] + self.uploadsMount,
    volumes:: [volume.fromSecret('gcs-auth', 'gcs-auth')] + self.uploadsVolume,

    local backup_container = _container(self.env, creds, self.mounts),
    backup_cron: cronjob.new(db_name)
                 + cronjob.mixin.metadata.withName('%s-backup' % db_name)
                 + cronjob.mixin.spec.withSchedule('0 0 * * *')
                 + cronjob.mixin.spec.withSuccessfulJobsHistoryLimit(1)
                 + cronjob.mixin.spec.withFailedJobsHistoryLimit(1)
                 + cronjob.mixin.spec.jobTemplate.spec.template.spec.withContainers([backup_container])
                 + cronjob.mixin.spec.jobTemplate.spec.template.spec.withRestartPolicy('OnFailure')
                 + cronjob.mixin.spec.jobTemplate.spec.template.spec.withVolumes(self.volumes),
  }
  ,

  withSchedule(schedule):: {
    backup_cron+: cronjob.mixin.spec.withSchedule(schedule),
  },

  withBackupPath(path, newerThanSeconds):: {
    env+:: {
      BACKUP_PATH: '/backups',
      NEWER_THAN_SECONDS: '%d' % newerThanSeconds,
    },
    mounts+:: [mount.new('backups', '/backups')],
    volumes+:: [volume.fromHostPath('backups', path)],
  },

  newRestoreJob(db_name, db_pass, bucket, creds, path='/uploads', domain=null, replace=null, from=db_name): {
    env:: {
      CMD: 'restore-db,restore-uploads',
      BUCKET: bucket,
      DB_NAME: db_name,
      DB_HOST: 'mysql.mysql',
      DB_PASS: db_pass,
      DB_USER: db_name,
    },

    uploadsMount:: [mount.new('uploads', '/uploads')],
    uploadsVolume:: [volume.fromPersistentVolumeClaim('uploads', 'uploads')],
    mounts:: [mount.new('gcs-auth', '/var/run/secrets/gcs-auth', true)] + self.uploadsMount,
    volumes:: [volume.fromSecret('gcs-auth', 'gcs-auth')] + self.uploadsVolume,
    local volumes = self.volumes,

    local restore_container = _container(self.env, creds, self.mounts, domain, replace, from),
    restore_job: cronjob.new()
                 + cronjob.mixin.metadata.withName('%s-restore' % db_name)
                 + cronjob.mixin.spec.withSchedule('0 0 31 2 *')  // i.e. never. will be run manually
                 + cronjob.mixin.spec.withSuccessfulJobsHistoryLimit(1)
                 + cronjob.mixin.spec.withFailedJobsHistoryLimit(1)
                 + cronjob.mixin.spec.jobTemplate.spec.template.spec.withContainers([restore_container])
                 + cronjob.mixin.spec.jobTemplate.spec.template.spec.withRestartPolicy('Never')
                 + cronjob.mixin.spec.jobTemplate.spec.template.spec.withVolumes(volumes),
  },

  withoutUploadsVolume():: {
    uploadsTasks:: '',
    uploadsMount:: [],
    uploadsVolume:: [],
  },
}
