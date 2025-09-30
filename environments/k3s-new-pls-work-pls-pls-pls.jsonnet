{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'environments/k3s',
  },

  spec: {
    apiServer: 'https://100.117.59.71:6443',
    namespace: 'prod',
    resourceDefaults: {},
    expectVersions: {},
    injectLabels: true,
  },

  data: {
    local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet',
    local k = import 'github.com/jsonnet-libs/k8s-libsonnet/1.33/main.libsonnet',
    local m = import 'github.com/jsonnet-libs/metallb-libsonnet/0.14/main.libsonnet',
    local helm = tanka.helm.new(std.thisFile),
    local ingressTailscale = import '../lib/ingressTailscale.jsonnet',

    local namespace = k.core.v1.namespace,
    local container = k.core.v1.container,
    local containerPort = k.core.v1.containerPort,
    local deployment = k.apps.v1.deployment,
    local persistentVolumeClaim = k.core.v1.persistentVolumeClaim,
    local service = k.core.v1.service,
    local servicePort = k.core.v1.servicePort,
    local ipAddressPool = m.metallb.v1beta1.ipAddressPool,
    local l2Advertisement = m.metallb.v1beta1.l2Advertisement,

    config:: {
      global: {
        namespace: 'prod',
      },
    },

    k3s: {
      prod: namespace.new(name=$.data.config.global.namespace),

      longhorn_sealedsecret: import '../secrets/cifs-secret.sealed.json',
      tailscale_sealedsecret: import '../secrets/operator-oauth.sealed.json',
      vaultwarden_sealedsecret: import '../secrets/vaultwarden.sealed.json',
      homarr_sealedsecret: import '../secrets/homarr.sealed.json',
      hetznerddns_sealedsecret: import '../secrets/hetznerddns.sealed.json',
      minio_sealedsecret: import '../secrets/minio.sealed.json',
      tuwunel_sealedsecret: import '../secrets/tuwunel.sealed.json',

      longhorn: {
        local name = 'longhorn',
        local port = 80,
        longhorn: helm.template(name=name, chart='../lib/charts/longhorn', conf={
          namespace: $.data.config.global.namespace,
          values: {
            persistence: {
              defaultClassReplicaCount: 1,
            },
            defaultSettings: {
              defaultReplicaCount: 1,
            },
          },
        }),
        ingress: ingressTailscale(name=name, port=port, svcName='longhorn-frontend'),
      },

      metallb: {
        local name = 'metallb',
        metallb: helm.template(name=name, chart='../lib/charts/metallb', conf={
          namespace: $.data.config.global.namespace,
        }),
        ips: ipAddressPool.new(name='homelab')
             + ipAddressPool.spec.withAddresses(addresses=[
               '10.20.0.150-10.20.0.160',
             ]),
        advertisement: l2Advertisement.new(name='l2advertisement')
                       + l2Advertisement.spec.withIpAddressPools(ipAddressPools='homelab'),
      },

      sealedsecrets: {
        local name = 'sealedsecrets',
        sealedsecrets: helm.template(name=name, chart='../lib/charts/sealed-secrets', conf={
          namespace: $.data.config.global.namespace,
          values: {
            secretName: 'sealed-secrets-secret',
          },
        }),
      },

      tailscale_operator: {
        local name = 'tailscale',
        tailscale_operator: helm.template(name=name, chart='../lib/charts/tailscale-operator', conf={
          namespace: $.data.config.global.namespace,
        }),
      },

      portainer: {
        local name = 'portainer',
        local port = 9000,
        portainer: helm.template(name=name, chart='../lib/charts/portainer', conf={
          namespace: $.data.config.global.namespace,
          values: {
            persistence: {
              existingClaim: 'portainer',
            },
          },
        }),
        ingress: ingressTailscale(name=name, port=port),
      },

      vaultwarden: {
        local name = 'vaultwarden',
        local port = 80,
        vaultwarden: helm.template(name=name, chart='../lib/charts/vaultwarden', conf={
          namespace: $.data.config.global.namespace,
          values: {
            vaultwarden: {
              domain: 'https://%s.wild-fahrenheit.ts.net' % name,
              admin: {
                enabled: true,
                existingSecret: 'vaultwarden-secret',
              },
            },
            persistence: {
              enabled: true,
              size: '10Gi',
              existingClaim: 'vaultwarden',
            },
          },
        }),
        ingress: ingressTailscale(name=name, port=port, funnel=true),
      },

      adguardhome: {
        local name = 'adguardhome',
        local image = 'adguard/adguardhome:latest',
        local port = 3000,
        local ip = '10.20.0.150',
        deployment: deployment.new(
                      name=name,
                      replicas=1,
                      containers=[
                        container.new(name=name, image=image)
                        + container.withPorts([
                          containerPort.newNamed(name=name, containerPort=port),
                          containerPort.newNamed(name='dns', containerPort=53),
                        ]),
                      ],
                    )
                    + deployment.pvcVolumeMount(name=name + '-work', path='/opt/adguardhome/work')
                    + deployment.pvcVolumeMount(name=name + '-config', path='/opt/adguardhome/conf'),
        work: persistentVolumeClaim.new(name=name + '-work')
              + persistentVolumeClaim.mixin.spec.withAccessModes(accessModes=['ReadWriteOnce'])
              + persistentVolumeClaim.mixin.spec.resources.withRequests(requests={ storage: '1Gi' }),
        config: persistentVolumeClaim.new(name=name + '-config')
                + persistentVolumeClaim.mixin.spec.withAccessModes(accessModes=['ReadWriteOnce'])
                + persistentVolumeClaim.mixin.spec.resources.withRequests(requests={ storage: '1Gi' }),
        service: service.new(name=name, selector={ name: name }, ports=[
                   servicePort.newNamed(name=name, port=port, targetPort=port),
                 ])
                 + service.mixin.spec.withType('ClusterIP'),
        serviceDns: service.new(name='adguardhome-dns', selector={ name: name }, ports=[
                      servicePort.newNamed(name='dns-tcp', port=53, targetPort=53)
                      + { protocol: 'TCP' },
                      servicePort.newNamed(name='dns-udp', port=53, targetPort=53)
                      + { protocol: 'UDP' },
                    ])
                    + service.mixin.spec.withType(type='LoadBalancer')
                    + service.mixin.spec.withLoadBalancerIP(loadBalancerIP=ip),
        ingress: ingressTailscale(name=name, port=port),
      },

      davmail: {
        local name = 'davmail',
        local image = 'kran0/davmail-docker:latest',
        local port = 1080,
        deployment: deployment.new(
                      name=name,
                      replicas=1,
                      containers=[
                        container.new(name=name, image=image)
                        + container.withPorts([
                          containerPort.newNamed(name=name, containerPort=port),
                        ]),
                      ],
                    )
                    + deployment.pvcVolumeMount(name=name, path='/davmail-config'),
        service: service.new(name=name, selector={ name: name }, ports=[
          servicePort.newNamed(name=name, port=port, targetPort=port),
        ]),
        ingress: ingressTailscale(name=name, port=port, funnel=true),
      },

      homarr: {
        local name = 'homarr',
        local image = 'ghcr.io/homarr-labs/homarr:latest',
        local port = 7575,
        deployment: deployment.new(
                      name=name,
                      replicas=1,
                      containers=[
                        container.new(name=name, image=image)
                        + container.withPorts([
                          containerPort.newNamed(name=name, containerPort=port),
                        ])
                        + container.withEnvFrom([{ secretRef: { name: 'homarr-secret' } }]),
                      ],
                    )
                    + deployment.pvcVolumeMount(name=name, path='/appdata'),
        service: service.new(name=name, selector={ name: name }, ports=[
          servicePort.newNamed(name=name, port=port, targetPort=port),
        ]),
        ingress: ingressTailscale(name=name, port=port),
      },

      homeassistant: {
        local name = 'homeassistant',
        local image = 'linuxserver/homeassistant:latest',
        local port = 8123,
        deployment: deployment.new(
                      name=name,
                      replicas=1,
                      containers=[
                        container.new(name=name, image=image)
                        + container.withPorts([
                          containerPort.newNamed(name=name, containerPort=port),
                        ]),
                      ],
                    )
                    + deployment.pvcVolumeMount(name=name + '-config', path='/config'),
        config: persistentVolumeClaim.new(name=name + '-config')
                + persistentVolumeClaim.mixin.spec.withAccessModes(accessModes=['ReadWriteOnce'])
                + persistentVolumeClaim.mixin.spec.resources.withRequests(requests={ storage: '1Gi' }),
        service: service.new(name=name, selector={ name: name }, ports=[
          servicePort.newNamed(name=name, port=port, targetPort=port),
        ]),
        ingress: ingressTailscale(name=name, port=port),
      },

      privatebin: {
        local name = 'privatebin',
        local image = 'privatebin/fs:latest',
        local port = 8080,
        deployment: deployment.new(
                      name=name,
                      replicas=1,
                      containers=[
                        container.new(name=name, image=image)
                        + container.withPorts([
                          containerPort.newNamed(name=name, containerPort=port),
                        ]),
                      ],
                    )
                    + deployment.pvcVolumeMount(name=name + '-data', path='/srv/data'),
        config: persistentVolumeClaim.new(name=name + '-data')
                + persistentVolumeClaim.mixin.spec.withAccessModes(accessModes=['ReadWriteOnce'])
                + persistentVolumeClaim.mixin.spec.resources.withRequests(requests={ storage: '1Gi' }),
        service: service.new(name=name, selector={ name: name }, ports=[
          servicePort.newNamed(name=name, port=port, targetPort=port),
        ]),
        ingress: ingressTailscale(name=name, port=port, funnel=true),
      },

      servarr: {
        local mediaName = 'media',
        local jellyfinName = 'jellyfin',
        local jellyfinImage = 'linuxserver/jellyfin:latest',
        local jellyfinPort = 8096,
        local wizarrName = 'wizarr',
        local wizarrImage = 'ghcr.io/wizarrrr/wizarr:latest',
        local wizarrPort = 5690,

        jellyfin: deployment.new(
                    name=jellyfinName,
                    replicas=1,
                    containers=[
                      container.new(name=jellyfinName, image=jellyfinImage)
                      + container.withPorts([
                        containerPort.newNamed(name=jellyfinName, containerPort=jellyfinPort),
                      ]),
                      container.new(name='rsync', image='linuxserver/openssh-server:latest')
                      + container.withPorts([
                        containerPort.newNamed(name='ssh', containerPort=2222),
                      ])
                      + container.withEnv(env=[
                        { name: 'PUBLIC_KEY', value: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC0P7n8nCfFc79DDIEQfVzRZ+zaX3L9F8NRqsXoirdWL' },
                        { name: 'DOCKER_MODS', value: 'linuxserver/mods:openssh-server-rsync' },
                      ]),
                    ],
                  )
                  + deployment.pvcVolumeMount(name='servarr-jellyfin', path='/config')
                  + deployment.pvcVolumeMount(name='media', path='/media'),
        service: service.new(name=jellyfinName, selector={ name: jellyfinName }, ports=[
          servicePort.newNamed(name=jellyfinName, port=jellyfinPort, targetPort=jellyfinPort),
          servicePort.newNamed(name='ssh', port=2222, targetPort=2222),
        ]),
        ingress: ingressTailscale(name=jellyfinName, port=jellyfinPort, funnel=true),

        wizarr: deployment.new(
                  name=wizarrName,
                  replicas=1,
                  containers=[
                    container.new(name=wizarrName, image=wizarrImage)
                    + container.withPorts([
                      containerPort.newNamed(name=wizarrName, containerPort=wizarrPort),
                    ]),
                  ],
                )
                + deployment.pvcVolumeMount(name=wizarrName + '-database', path='/data/database')
                + deployment.pvcVolumeMount(name=wizarrName + '-wizard-steps', path='/data/wizard_steps'),
        wizarrDatabase: persistentVolumeClaim.new(name=wizarrName + '-database')
                        + persistentVolumeClaim.mixin.spec.withAccessModes(accessModes=['ReadWriteOnce'])
                        + persistentVolumeClaim.mixin.spec.resources.withRequests(requests={ storage: '1Gi' }),
        wizarrSteps: persistentVolumeClaim.new(name=wizarrName + '-wizard-steps')
                     + persistentVolumeClaim.mixin.spec.withAccessModes(accessModes=['ReadWriteOnce'])
                     + persistentVolumeClaim.mixin.spec.resources.withRequests(requests={ storage: '1Gi' }),
        wizarrService: service.new(name=wizarrName, selector={ name: wizarrName }, ports=[
          servicePort.newNamed(name=wizarrName, port=wizarrPort, targetPort=wizarrPort),
        ]),
        wizarrIngress: ingressTailscale(name=wizarrName, port=wizarrPort),
      },

      tmt2: {
        local name = 'tmt2',
        local image = 'jensforstmann/tmt2:latest',
        local port = 8080,
        deployment: deployment.new(
                      name=name,
                      replicas=1,
                      containers=[
                        container.new(name=name, image=image)
                        + container.withPorts([
                          containerPort.newNamed(name=name, containerPort=port),
                        ]),
                      ],
                    )
                    + deployment.pvcVolumeMount(name=name + '-data', path='/app/backend/storage'),
        config: persistentVolumeClaim.new(name=name + '-data')
                + persistentVolumeClaim.mixin.spec.withAccessModes(accessModes=['ReadWriteOnce'])
                + persistentVolumeClaim.mixin.spec.resources.withRequests(requests={ storage: '1Gi' }),
        service: service.new(name=name, selector={ name: name }, ports=[
          servicePort.newNamed(name=name, port=port, targetPort=port),
        ]),
        ingress: ingressTailscale(name=name, port=port, funnel=true),
      },

      metube: {
        local name = 'metube',
        local image = 'ghcr.io/alexta69/metube:latest',
        local port = 8081,
        deployment: deployment.new(
                      name=name,
                      replicas=1,
                      containers=[
                        container.new(name=name, image=image)
                        + container.withPorts([
                          containerPort.newNamed(name=name, containerPort=port),
                        ]),
                      ],
                    )
                    + deployment.pvcVolumeMount(name=name + '-data', path='/downloads'),
        config: persistentVolumeClaim.new(name=name + '-data')
                + persistentVolumeClaim.mixin.spec.withAccessModes(accessModes=['ReadWriteOnce'])
                + persistentVolumeClaim.mixin.spec.resources.withRequests(requests={ storage: '1Gi' }),
        service: service.new(name=name, selector={ name: name }, ports=[
          servicePort.newNamed(name=name, port=port, targetPort=port),
        ]),
        ingress: ingressTailscale(name=name, port=port),
      },

      softserve: {
        local name = 'softserve',
        local image = 'charmcli/soft-serve:latest',
        local port = 23231,
        local ip = '10.20.0.151',
        deployment: deployment.new(
                      name=name,
                      replicas=1,
                      containers=[
                        container.new(name=name, image=image)
                        + container.withPorts([
                          containerPort.newNamed(name=name, containerPort=port),
                        ])
                        + container.mixin.withEnv(env=[
                          { name: 'SOFT_SERVE_INITIAL_ADMIN_KEYS', value: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC0P7n8nCfFc79DDIEQfVzRZ+zaX3L9F8NRqsXoirdWL' },
                          { name: 'SOFT_SERVE_SSH_PUBLIC_URL', value: 'ssh://10.20.0.151:2222' },
                        ]),
                      ],
                    )
                    + deployment.pvcVolumeMount(name=name + '-data', path='/soft-serve'),
        config: persistentVolumeClaim.new(name=name + '-data')
                + persistentVolumeClaim.mixin.spec.withAccessModes(accessModes=['ReadWriteOnce'])
                + persistentVolumeClaim.mixin.spec.resources.withRequests(requests={ storage: '5Gi' }),
        serviceDns: service.new(name=name, selector={ name: name }, ports=[
                      servicePort.newNamed(name='ssh', port=2222, targetPort=port),
                    ])
                    + service.mixin.spec.withType(type='LoadBalancer')
                    + service.mixin.spec.withLoadBalancerIP(loadBalancerIP=ip),
      },

      hetznerddns: {
        local name = 'hetznerddns',
        local image = 'filiparag/hetzner_ddns:latest',
        deployment: deployment.new(
                      name=name,
                      replicas=1,
                      containers=[
                        container.new(name=name, image=image)
                        + container.withVolumeMounts(volumeMounts=[{ name: 'config-' + name, mountPath: '/etc/hetzner_ddns.conf', subPath: 'hetzner_ddns.conf' }]),
                      ],
                    )
                    + { spec+: { template+: { spec+: { volumes+: [{ name: 'config-' + name, secret: { secretName: 'hetznerddns-secret' } }] } } } },
      },

      teamspeak: {
        local name = 'teamspeak',
        local image = 'mbentley/teamspeak:latest',
        deployment: deployment.new(
                      name=name,
                      replicas=1,
                      containers=[
                        container.new(name=name, image=image)
                        + container.withPorts([
                          containerPort.newNamedUDP(name='ts', containerPort=9987),
                          containerPort.newNamed(name='file', containerPort=30033),
                          containerPort.newNamed(name='query', containerPort=10011),
                        ])
                        + container.mixin.withEnv(env={ name: 'PUID', value: '503' })
                        + container.mixin.withEnv(env={ name: 'PGID', value: '503' })
                        + container.mixin.withEnv(env={ name: 'TS3SERVER_GDPR_SAVE', value: 'true' })
                        + container.mixin.withEnv(env={ name: 'TS3SERVER_LICENSE', value: 'accept' }),
                      ],
                    )
                    + deployment.pvcVolumeMount(name=name + '-data', path='/data'),
        config: persistentVolumeClaim.new(name=name + '-data')
                + persistentVolumeClaim.mixin.spec.withAccessModes(accessModes=['ReadWriteOnce'])
                + persistentVolumeClaim.mixin.spec.resources.withRequests(requests={ storage: '5Gi' }),
        service: service.new(name=name, selector={ name: name }, ports=[
                   servicePort.newNamed(name='ts', port=9987, targetPort=9987),
                   servicePort.newNamed(name='file', port=30033, targetPort=30033),
                   servicePort.newNamed(name='query', port=10011, targetPort=10011),
                 ])
                 + service.mixin.spec.withType(type='NodePort'),
      },

      tuwunel: {
        local name = 'tuwunel',
        local port = 80,
        tuwunel: helm.template(name=name, chart='../lib/charts/conduwuit', conf={
          namespace: $.data.config.global.namespace,
          values: {
            image: {
              repository: 'ghcr.io/matrix-construct/tuwunel',
              tag: 'latest',
            },
            service: {
              clusterIP: '',
            },
            config: {
              server_name: 'tuwunel.wild-fahrenheit.ts.net',
              allow_registration: 'true',
              allow_federation: 'true',
              trusted_servers: ['matrix.org'],
            },
            extraEnv: [{ name: 'TUWUNEL_REGISTRATION_TOKEN', value: { valueFrom: { secretKeyRef: { name: 'tuwunel-secret', key: 'registration_token' } } } }],
          },
        }),
        ingress: ingressTailscale(name=name, port=port, svcName='tuwunel-conduwuit', funnel=true),
      },

      actualbudget: {
        local name = 'actualbudget',
        local image = 'docker.io/actualbudget/actual-server:latest',
        local port = 5006,
        deployment: deployment.new(
                      name=name,
                      replicas=1,
                      containers=[
                        container.new(name=name, image=image)
                        + container.withPorts([
                          containerPort.newNamed(name=name, containerPort=port),
                        ]),
                      ],
                    )
                    + deployment.pvcVolumeMount(name=name + '-data', path='/data'),
        config: persistentVolumeClaim.new(name=name + '-data')
                + persistentVolumeClaim.mixin.spec.withAccessModes(accessModes=['ReadWriteOnce'])
                + persistentVolumeClaim.mixin.spec.resources.withRequests(requests={ storage: '5Gi' }),
        service: service.new(name=name, selector={ name: name }, ports=[
          servicePort.newNamed(name=name, port=port, targetPort=port),
        ]),
        ingress: ingressTailscale(name=name, port=port),
      },

      archivebox: {
        local name = 'archivebox',
        local image = 'docker.io/archivebox/archivebox:latest',
        local port = 8000,
        deployment: deployment.new(
                      name=name,
                      replicas=1,
                      containers=[
                        container.new(name=name, image=image)
                        + container.withPorts([
                          containerPort.newNamed(name=name, containerPort=port),
                        ])
                        + container.withEnv(env=[
                          { name: 'CSRF_TRUSTED_ORIGINS', value: 'https://archivebox.wild-fahrenheit.ts.net' },
                        ]),
                      ],
                    )
                    + deployment.pvcVolumeMount(name=name + '-data', path='/data'),
        config: persistentVolumeClaim.new(name=name + '-data')
                + persistentVolumeClaim.mixin.spec.withAccessModes(accessModes=['ReadWriteOnce'])
                + persistentVolumeClaim.mixin.spec.resources.withRequests(requests={ storage: '5Gi' }),
        service: service.new(name=name, selector={ name: name }, ports=[
          servicePort.newNamed(name=name, port=port, targetPort=port),
        ]),
        ingress: ingressTailscale(name=name, port=port),
      },

      uptimekuma: {
        local name = 'uptimekuma',
        local port = 3001,
        tuwunel: helm.template(name=name, chart='../lib/charts/uptime-kuma', conf={
          namespace: $.data.config.global.namespace,
        }),
        ingress: ingressTailscale(name=name, port=port, svcName='uptimekuma-uptime-kuma', funnel=true),
      },

    },
  },
}
