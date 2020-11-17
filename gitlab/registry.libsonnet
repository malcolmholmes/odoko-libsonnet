{
  local secret = $.core.v1.secret,

  local gitlab_auth = (std.base64(importstr 'secrets/gitlab.json')),

  secret:: 'gitlab',

  gitlab_secret:
    secret.new(
      self.secret,
      { '.dockerconfigjson': gitlab_auth },
      'kubernetes.io/dockerconfigjson',
    ) +
    secret.mixin.metadata.withNamespace($._config.namespace),
}
