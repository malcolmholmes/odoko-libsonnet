local k = import 'ksonnet-util/kausal.libsonnet';
{
  local clusterRole = k.rbac.v1.clusterRole,
  local clusterRoleBinding = k.rbac.v1.clusterRoleBinding,
  local roleRule = k.rbac.v1.clusterRole.rulesType,
  local roleBinding = k.rbac.v1.roleBinding,
  local service = k.core.v1.service,
  local servicePort = service.mixin.spec.portsType,
  local serviceAccount = k.core.v1.serviceAccount,
  local container = k.apps.v1.deployment.mixin.spec.template.spec.containersType,
  local deployment = k.apps.v1.deployment,
  local configMap = k.core.v1.configMap,
  local role = k.rbac.v1.role,

  _images+:: {
    nginx: 'quay.io/kubernetes-ingress-controller/nginx-ingress-controller:0.22.0',
  },

  _config+:: {
    ingress: {
      replicas: 1,
      ipAddress: error 'IP address required by ingress controller',
      ports: [{
        name: 'ingress',
        containerPort: 8080,
      }],
    },
  },

  nginx_ingress_clusterrole:
    clusterRole.new() +
    clusterRole.mixin.metadata.withName('nginx-ingress-clusterrole') +
    clusterRole.withRulesMixin([
      roleRule.new() +
      roleRule.withApiGroups('') +
      roleRule.withResources(['configmaps', 'pods', 'secrets', 'nodes', 'namespaces', 'endpoints']) +
      roleRule.withVerbs(['list', 'watch', 'get']),
      roleRule.new() +
      roleRule.withApiGroups('') +
      roleRule.withResources(['nodes']) +
      roleRule.withVerbs(['get']),
      roleRule.new() +
      roleRule.withApiGroups('') +
      roleRule.withResources(['services']) +
      roleRule.withVerbs(['get', 'list', 'watch']),
      roleRule.new() +
      roleRule.withApiGroups('extensions') +
      roleRule.withResources(['ingresses']) +
      roleRule.withVerbs(['get', 'list', 'watch']),
      roleRule.new() +
      roleRule.withApiGroups('') +
      roleRule.withResources(['events', 'configmaps']) +
      roleRule.withVerbs(['create', 'patch', 'update']),
      roleRule.new() +
      roleRule.withApiGroups('extensions') +
      roleRule.withResources(['ingresses/status']) +
      roleRule.withVerbs(['update']),
    ]),

  nginx_ingress_role:
    role.new() +
    role.mixin.metadata.withNamespace($._config.namespace) +
    role.mixin.metadata.withName('nginx-ingress-role') +
    role.withRulesMixin([
      roleRule.new() +
      roleRule.withApiGroups('') +
      roleRule.withResources(['configmaps', 'pods', 'secrets', 'namespaces']) +
      roleRule.withVerbs(['get']),
      roleRule.new() +
      roleRule.withApiGroups('') +
      roleRule.withResources(['configmaps']) +
      roleRule.withResourceNames(['ingress-controller-leader-nginx']) +
      roleRule.withVerbs(['get', 'update']),
      roleRule.new() +
      roleRule.withApiGroups('') +
      roleRule.withResources(['configmaps']) +
      roleRule.withVerbs(['create']),
      roleRule.new() +
      roleRule.withApiGroups('') +
      roleRule.withResources(['endpoints']) +
      roleRule.withVerbs(['get']),
    ]),

  ingress_nginx_role_nisa_binding:
    roleBinding.new() +
    roleBinding.mixin.metadata.withName('nginx-ingress-role-nisa-binding') +
    roleBinding.mixin.metadata.withNamespace($._config.namespace) +
    roleBinding.mixin.roleRef.withApiGroup('rbac.authorization.k8s.io') +
    roleBinding.mixin.roleRef.withKind('Role') +
    roleBinding.mixin.roleRef.withName('nginx-ingress-role') +
    roleBinding.withSubjectsMixin({
      kind: 'ServiceAccount',
      name: 'nginx-ingress-serviceaccount',
      namespace: $._config.namespace,
    }),

  ingress_nginx_clusterrole_nisa_binding:
    clusterRoleBinding.new() +
    clusterRoleBinding.mixin.metadata.withName('nginx-ingress-clusterrole-nisa-binding') +
    clusterRoleBinding.mixin.roleRef.withApiGroup('rbac.authorization.k8s.io') +
    clusterRoleBinding.mixin.roleRef.withKind('ClusterRole') +
    clusterRoleBinding.mixin.roleRef.withName('nginx-ingress-clusterrole') +
    clusterRoleBinding.withSubjectsMixin({
      kind: 'ServiceAccount',
      name: 'nginx-ingress-serviceaccount',
      namespace: $._config.namespace,
    }),

  ingress_nginx_rbac:  // NOTE: this may not be needed with the roles/clusterroles/bindings above
    roleBinding.new() +
    roleBinding.mixin.metadata.withName('grant-ingress-nginx-default-service-account-clusterrole-edit-access') +
    roleBinding.mixin.metadata.withNamespace($._config.namespace) +
    roleBinding.mixin.roleRef.withApiGroup('rbac.authorization.k8s.io') +
    roleBinding.mixin.roleRef.withKind('ClusterRole') +
    roleBinding.mixin.roleRef.withName('edit') +
    roleBinding.withSubjectsMixin({
      kind: 'ServiceAccount',
      name: 'default',
      namespace: $._config.namespace,
    }),


  ingress_service_account:
    serviceAccount.new('nginx-ingress-serviceaccount') +
    serviceAccount.mixin.metadata.withNamespace($._config.namespace),

  ingress_service: service.new(
                     'ingress-nginx',
                     {
                       app: 'ingress',
                       'app.kubernetes.io/name': 'ingress-nginx',
                       'app.kubernetes.io/part-of': 'ingress-nginx',
                     },
                     [
                       servicePort.newNamed('http', 80, 80) + servicePort.withProtocol('TCP'),
                       servicePort.newNamed('https', 443, 443) + servicePort.withProtocol('TCP'),
                     ]
                   )
                   + service.mixin.spec.withType('LoadBalancer')
                   + service.mixin.spec.withLoadBalancerIp($._config.ingress.ipAddress)
                   + service.mixin.metadata.withNamespace($._config.namespace)
                   + service.mixin.spec.withSelector({ name: 'ingress-nginx' })
                   + service.mixin.spec.withExternalTrafficPolicy('Local')
  ,

  nginx_configuration_config_map:
    configMap.new('nginx-configuration')
    + configMap.mixin.metadata.withNamespace($._config.namespace)
    + configMap.withData({})
  ,

  nginx_tcp_config_map:
    configMap.new('tcp-services')
    + configMap.mixin.metadata.withNamespace($._config.namespace)
    + configMap.withData({})
  ,

  nginx_udp_config_map:
    configMap.new('udp-services')
    + configMap.mixin.metadata.withNamespace($._config.namespace)
    + configMap.withData({})
  ,

  local ingress_nginx_ports = [
    {
      name: 'http',
      containerPort: 80,
    },
    {
      name: 'https',
      containerPort: 443,
    },
  ],

  local ingress_nginx_container = container.new('nginx-ingress-controller', $._images.nginx)
                                  + container.withArgs([
                                    '/nginx-ingress-controller',
                                    '--configmap=' + $._config.namespace + '/nginx-configuration',
                                    '--tcp-services-configmap=' + $._config.namespace + '/tcp-services',
                                    '--udp-services-configmap=' + $._config.namespace + '/udp-services',
                                    '--publish-service=' + $._config.namespace + '/ingress-nginx',
                                    '--annotations-prefix=nginx.ingress.kubernetes.io',
                                  ])
                                  + container.withEnv([
                                    container.envType.fromFieldPath('POD_NAME', 'metadata.name'),
                                    container.envType.fromFieldPath('POD_NAMESPACE', 'metadata.namespace'),
                                  ])
                                  + container.withPorts($._config.ingress.ports)
                                  + container.mixin.securityContext.withRunAsUser(33)  // www-data
                                  + container.mixin.securityContext.withAllowPrivilegeEscalation(true)
                                  + container.mixin.securityContext.capabilities.withDrop('ALL')
                                  + container.mixin.securityContext.capabilities.withAdd('NET_BIND_SERVICE')
                                  + container.mixin.livenessProbe.httpGet.withPath('/healthz')
                                  + container.mixin.livenessProbe.httpGet.withPort(10254)
                                  + container.mixin.livenessProbe.httpGet.withScheme('HTTP')
                                  + container.mixin.livenessProbe.withPeriodSeconds(10)
                                  + container.mixin.livenessProbe.withSuccessThreshold(1)
                                  + container.mixin.livenessProbe.withFailureThreshold(3)
                                  + container.mixin.livenessProbe.withInitialDelaySeconds(10)
                                  + container.mixin.livenessProbe.withTimeoutSeconds(10)
                                  + container.mixin.readinessProbe.httpGet.withPath('/healthz')
                                  + container.mixin.readinessProbe.httpGet.withPort(10254)
                                  + container.mixin.readinessProbe.httpGet.withScheme('HTTP')
                                  + container.mixin.readinessProbe.withPeriodSeconds(10)
                                  + container.mixin.readinessProbe.withSuccessThreshold(1)
                                  + container.mixin.readinessProbe.withFailureThreshold(3)
                                  + container.mixin.readinessProbe.withTimeoutSeconds(10),

  local nginxLabels = { name: 'ingress-nginx' },

  ingress_nginx_deployment: deployment.new('ingress-nginx', $._config.ingress.replicas, [ingress_nginx_container])
                            + deployment.mixin.metadata.withNamespace($._config.namespace)
                            + deployment.mixin.spec.template.spec.withServiceAccountName('nginx-ingress-serviceaccount')
                            + deployment.mixin.spec.template.metadata.withAnnotations({
                              'prometheus.io/scrape': 'true',
                              'prometheus.io/port': '10254',
                            })
                            + deployment.mixin.metadata.withLabels(nginxLabels)
                            + deployment.mixin.spec.template.metadata.withLabels(nginxLabels)
                            + deployment.mixin.spec.selector.withMatchLabels(nginxLabels),

}
