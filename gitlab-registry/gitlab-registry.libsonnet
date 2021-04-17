local k = import 'ksonnet-util/kausal.libsonnet';
{
  local secret = k.core.v1.secret,
  secret:: 'gitlab',

  new(auth):: {
    local gitlab_auth = std.base64(auth),
    gitlab_secret: secret.new($.secret, { '.dockerconfigjson': gitlab_auth }, 'kubernetes.io/dockerconfigjson'),
  },
}
