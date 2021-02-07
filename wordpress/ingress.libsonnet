local k = import 'ksonnet-util/kausal.libsonnet';

{
  local ingress = k.extensions.v1beta1.ingress,
  local ingressRule = k.networking.v1beta1.ingressRule,
  local httpIngressPath = k.networking.v1beta1.httpIngressPath,

  addIngress(name, domains=[], extraDomains=[], zone=null, domain='', service='')::

    local serviceName = if service == '' then name else service;

    local domainlist = (
      if std.length(domains) == 0 then
        [domain, 'www.%s' % domain]
      else domains
    ) + extraDomains;

    local rule(dom) = ingressRule.http.withPaths(
                        httpIngressPath.withPath('/')
                        + httpIngressPath.backend.withServiceName(serviceName)
                        + httpIngressPath.backend.withServicePort(80)
                      )
                      + ingressRule.withHost(dom)
    ;

    ingress.new()
    + ingress.mixin.metadata.withName(name)
    + ingress.mixin.spec.withTls({ hosts: domainlist, secretName: name })
    + ingress.mixin.metadata.withAnnotationsMixin({
      'kubernetes.io/tls-acme': 'true',
      //      'kubernetes.io/ingress.class': 'nginx',
      //'nginx.ingress.kubernetes.io/affinity-mode': 'persistent',
      'cert-manager.io/cluster-issuer': 'letsencrypt-prod',
      [if zone != null then 'odoko.com/dyn-dns-zone' else null]: zone,
    })
    //    + ingress.mixin.spec.backend.withServiceName(serviceName)
    //    + ingress.mixin.spec.backend.withServicePort(80)
    + ingress.mixin.spec.withRules(
      [
        rule(dom)
        for dom in domainlist
      ]
    )
  ,

  withIngress(domains=[], extraDomains=[], zone=null):: {
    local name = super.config.name,
    ingress: $.addIngress(name, domains, extraDomains, zone, domain=super.config.domain),
  },

  withHttpIngress():: {
    local name = super.config.name,
    local domain = super.config.domain,

    local rule(dom) = ingress.mixin.specType.rulesType.mixin.http.withPaths(
                        ingress.mixin.spec.rulesType.mixin.httpType.pathsType.withPath('/')
                        + ingress.mixin.specType.mixin.backend.withServiceName(name)
                        + ingress.mixin.specType.mixin.backend.withServicePort(80)
                      )
                      + ingress.mixin.spec.rulesType.withHost(dom)
    ,

    ingress: ingress.new()
             + ingress.mixin.metadata.withName(name)
             + ingress.mixin.metadata.withAnnotationsMixin({
               //              'kubernetes.io/ingress.class': 'nginx',
               'nginx.ingress.kubernetes.io/affinity-mode': 'persistent',
             })
             + ingress.mixin.spec.backend.mixinInstance({ serviceName: name, servicePort: 80 })
             + ingress.mixin.spec.withRules([rule(domain)]),
  },

  withTraefikIngress():: {
    ingress+: ingress.mixin.metadata.withAnnotationsMixin({
      'kubernetes.io/ingress.class': 'traefik',
      'traefik.ingress.kubernetes.io/preserve-host': 'true',
      'ingress.kubernetes.io/ssl-proxy-headers': 'https',
    }),
  },
}
