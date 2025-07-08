local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

function(name, size, accessModes=['ReadWriteOnce']) {
  pvc: k.core.v1.persistentVolumeClaim.new(name=name)
       + k.core.v1.persistentVolumeClaim.mixin.spec.withAccessModes(accessModes=accessModes)
       + k.core.v1.persistentVolumeClaim.mixin.spec.resources.withRequests(requests={ storage: size }),
}.pvc
