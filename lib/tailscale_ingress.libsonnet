local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

function(name, port, funnel=false) {
  local base = k.networking.v1.ingress.new(name=name)
               + k.networking.v1.ingress.mixin.spec.withIngressClassName(ingressClassName='tailscale')
               + k.networking.v1.ingress.mixin.spec.withTls(tls={ hosts: [name] })
               + k.networking.v1.ingress.mixin.spec.defaultBackend.service.port.withNumber(number=port)
               + k.networking.v1.ingress.mixin.spec.defaultBackend.service.withName(name=name),
  result: if funnel then
    base + k.networking.v1.ingress.mixin.metadata.withAnnotations(annotations={ 'tailscale.com/funnel': 'true' })
  else base,
}.result
