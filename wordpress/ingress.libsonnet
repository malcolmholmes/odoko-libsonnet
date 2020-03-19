local k = import 'ksonnet-util/kausal.libsonnet';

{
  local ingress = k.extensions.v1beta1.ingress,

  withIngress(extraDomains=[]):: {

    local name = super.config.name,
    local domain = super.config.domain,
    local root = 'www.%s' % domain,

    local rule(dom) = ingress.mixin.specType.rulesType.mixin.http.withPaths(
           ingress.mixin.spec.rulesType.mixin.httpType.pathsType.withPath('/')
           + ingress.mixin.specType.mixin.backend.withServiceName(name)
           + ingress.mixin.specType.mixin.backend.withServicePort(80))
           + ingress.mixin.spec.rulesType.withHost(dom)
           ,

    ingress: ingress.new()
      + ingress.mixin.metadata.withName(name)
      + ingress.mixin.spec.withTls({hosts:[ domain, root] + extraDomains, secretName: name})
      + ingress.mixin.metadata.withAnnotationsMixin({
        'kubernetes.io/tls-acme': 'true',
        'kubernetes.io/ingress.class': 'nginx',
        'nginx.ingress.kubernetes.io/affinity-mode': 'persistent',
      })
      + ingress.mixin.spec.backend.mixinInstance({serviceName: name, servicePort: 80})
      + ingress.mixin.spec.withRules(
          [rule(domain), rule(root)]
        + [
          rule(dom)
          for dom in extraDomains
          ]
        )
      ,
  }
}
