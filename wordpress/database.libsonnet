local k = import 'ksonnet-util/kausal.libsonnet';

{
  local container = k.core.v1.container,
  local job = k.batch.v1.job,

  withDatabase(root_password):: {
    local config = super.config,
    local _container = container.new(config.name + "-backup", $._images.wordpress)
      .withImagePullPolicy('Always')
      .withEnvMap({
        CMD: 'database',
        WORDPRESS_DB_NAME: config.name,
	    WORDPRESS_DB_ROOT_PASSWORD: root_password,
        WORDPRESS_DB_PASSWORD: config.db_pass,
      })
      ,

    job: job.new()
      + job.mixin.metadata.withName('%s-create-database' % super.config.name)
      + job.mixin.spec.template.spec.withContainers(_container)
      + job.mixin.spec.template.spec.withRestartPolicy('Never')
      ,
  },
}
