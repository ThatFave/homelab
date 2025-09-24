local k = import 'github.com/jsonnet-libs/k8s-libsonnet/1.33/main.libsonnet';

function(name, port, funnel=false, svcName='') {
  local realName = if !std.isEmpty(svcName) then svcName else name,
  local baseIngress =
    k.networking.v1.ingress.new(name)
    + k.networking.v1.ingress.spec.withIngressClassName('tailscale')
    + k.networking.v1.ingress.spec.defaultBackend.service.withName(realName)
    + k.networking.v1.ingress.spec.defaultBackend.service.port.withNumber(port)
    + k.networking.v1.ingress.spec.withTls([{ hosts: [name] }]),

  local ingress = if funnel then
    baseIngress + k.networking.v1.ingress.metadata.withAnnotations({
      'tailscale.com/funnel': 'true',
    })
  else baseIngress,

  result: {
    ingress: ingress,
  },
}.result
