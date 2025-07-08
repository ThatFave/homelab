local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local tailscale_ingress = import 'tailscale_ingress.libsonnet';
local persistentVolumeClaim = k.core.v1.persistentVolumeClaim;
local persistentVolume = k.core.v1.persistentVolume;
local containerPort = k.core.v1.containerPort;
local pvc = import 'volume_factory.libsonnet';
local helm = tanka.helm.new(std.thisFile);
local volumeMount = k.core.v1.volumeMount;
local deployment = k.apps.v1.deployment;
local secrets = import 'secrets.json';
local container = k.core.v1.container;
local namespace = k.core.v1.namespace;
local serviceFor = k.util.serviceFor;

{
  _config:: {
    global: {
      namespace: 'dev',
    },
    adguardhome: {
      name: 'adguardhome',
      image: 'adguard/adguardhome:latest',
      port: 3000,
      storage: '1Gi',
    },
    davmail: {
      name: 'davmail',
      image: 'kran0/davmail-docker:latest',
      port: 1080,
      storage: '1Gi',
    },
    descheduler: {
      name: 'descheduler',
    },
    homarr: {
      name: 'homarr',
      image: 'ghcr.io/homarr-labs/homarr:latest',
      port: 7575,
      storage: '50Mi',
    },
    homeassistant: {
      name: 'homeassistant',
      image: 'linuxserver/homeassistant:latest',
      port: 8123,
      storage: '1Gi',
    },
    metricsserver: {
      name: 'metricsserver',
    },
    syncthing: {
      name: 'syncthing',
      image: 'linuxserver/syncthing:latest',
      port: 8384,
      storage: '50Gi',
      smbName: 'syncthing-smb',
      smbImage: 'dockurr/samba:latest',
      smbPort: 445,
    },
    portainer: {
      name: 'portainer',
      image: 'portainer/portainer-ce:latest',
      port: 9000,
      storage: '1Gi',
    },
    privatebin: {
      name: 'privatebin',
      image: 'privatebin/fs:latest',
      port: 8080,
      storage: '1Gi',
    },
    vaultwarden: {
      name: 'vaultwarden',
      image: 'vaultwarden/server:latest',
      port: 80,
      storage: '15Gi',
    },
    servarr: {
      name: 'servarr',
      nfsServer: '100.97.177.7',
      nfsPath: '/media-library',
      nfsSize: '300Gi',
      nfsName: 'nfs',
      nfsAccessModes: ['ReadWriteMany'],
      jellyfinImage: 'linuxserver/jellyfin:latest',
      jellyfinPort: 8096,
      jellyfinSize: '1Gi',
      sonarrImage: 'linuxserver/sonarr:latest',
      sonarrPort: 8989,
      sonarrSize: '1Gi',
      qbittorrentImage: 'linuxserver/qbittorrent:latest',
      qbittorrentPort: 8080,
      qbittorrentSize: '1Gi',
      prowlarrImage: 'linuxserver/prowlarr:latest',
      prowlarrPort: 9696,
      prowlarrSize: '1Gi',
      radarrImage: 'linuxserver/radarr:latest',
      radarrPort: 7878,
      radarrSize: '1Gi',
      jellyseerrImage: 'ghcr.io/fallenbagel/jellyseerr:latest',
      jellyseerrPort: 5055,
      jellyseerrSize: '1Gi',
      flaresolverrImage: 'ghcr.io/flaresolverr/flaresolverr:latest',
      flaresolverrPort: 8191,
      wizarrImage: 'ghcr.io/wizarrrr/wizarr:latest',
      wizarrPort: 5690,
      wizarrSize: '1Gi',
    },
    tandoor: {
      name: 'tandoor',
      image: 'vabene1111/recipes:latest',
      port: 8080,
      storage: '15Gi',
    },
  },

  dev: namespace.new(name=$._config.global.namespace)
       + namespace.mixin.metadata.withLabels(labels={ 'goldilocks.fairwinds.com/enabled': 'true' }),

  adguardhome: {
    deployment: deployment.new(
                  name=$._config.adguardhome.name,
                  replicas=1,
                  containers=[
                    container.new(name=$._config.adguardhome.name, image=$._config.adguardhome.image)
                    + container.withPorts(containerPort.new(name=$._config.adguardhome.name, port=$._config.adguardhome.port)),
                  ],
                ) + deployment.pvcVolumeMount(name='%s-work' % $._config.adguardhome.name, path='/opt/adguardhome/work')
                + deployment.pvcVolumeMount(name='%s-config' % $._config.adguardhome.name, path='/opt/adguardhome/config'),
    work: pvc(name='%s-work' % $._config.adguardhome.name, size=$._config.adguardhome.storage),
    config: pvc(name='%s-config' % $._config.adguardhome.name, size=$._config.adguardhome.storage),
    service: serviceFor(deployment=self.deployment),
    ingress: tailscale_ingress(
      name=$._config.adguardhome.name,
      port=$._config.adguardhome.port,
    ),
  },

  davmail: {
    deployment: deployment.new(
      name=$._config.davmail.name,
      replicas=1,
      containers=[
        container.new(name=$._config.davmail.name, image=$._config.davmail.image)
        + container.withPorts(containerPort.new(name=$._config.davmail.name, port=$._config.davmail.port)),
      ],
    ) + deployment.pvcVolumeMount(name=$._config.davmail.name, path='/davmail-config'),
    config: pvc(name=$._config.davmail.name, size=$._config.davmail.storage),
    service: serviceFor(deployment=self.deployment),
    ingress: tailscale_ingress(
      name=$._config.davmail.name,
      port=$._config.davmail.port,
      funnel=true,
    ),
  },

  // descheduler: helm.template(name=$._config.descheduler.name, chart='../../lib/charts/descheduler', conf={
  //   namespace: $._config.global.namespace,
  // }),

  homarr: {
    deployment: deployment.new(
      name=$._config.homarr.name,
      replicas=1,
      containers=[
        container.new(name=$._config.homarr.name, image=$._config.homarr.image)
        + container.withPorts(containerPort.new(name=$._config.homarr.name, port=$._config.homarr.port))
        + container.withEnv(env={ name: 'SECRET_ENCRYPTION_KEY', value: secrets.homarr_secret_encryption_key })
        + container.withImagePullPolicy(imagePullPolicy='Always'),
      ],
    ) + deployment.pvcVolumeMount(name=$._config.homarr.name, path='/appdata'),
    appdata: pvc(name=$._config.homarr.name, size=$._config.homarr.storage),
    service: serviceFor(deployment=self.deployment),
    ingress: tailscale_ingress(
      name=$._config.homarr.name,
      port=$._config.homarr.port,
    ),
  },

  homeassistant: {
    deployment: deployment.new(
      name=$._config.homeassistant.name,
      replicas=1,
      containers=[
        container.new(name=$._config.homeassistant.name, image=$._config.homeassistant.image)
        + container.withPorts(containerPort.new(name=$._config.homeassistant.name, port=$._config.homeassistant.port)),
      ],
    ) + deployment.pvcVolumeMount(name=$._config.homeassistant.name, path='/config'),
    config: pvc(name=$._config.homeassistant.name, size=$._config.homeassistant.storage),
    service: serviceFor(deployment=self.deployment),
    ingress: tailscale_ingress(
      name=$._config.homeassistant.name,
      port=$._config.homeassistant.port,
    ),
  },

  // metricsserver: helm.template(name=$._config.metricsserver.name, chart='../../lib/charts/metrics-server', conf={
  //   namespace: $._config.global.namespace,
  // }),

  syncthing: {
    syncthing: deployment.new(
                  name=$._config.syncthing.name,
                  replicas=1,
                  containers=[
                    container.new(name=$._config.syncthing.name, image=$._config.syncthing.image)
                    + container.withPorts(ports=[
                      containerPort.new(name='webui', port=$._config.syncthing.port),
                      containerPort.new(name='listen-tcp', port=22000),
                      containerPort.newUDP(name='listen-udp', port=22000),
                      containerPort.newUDP(name='discovery', port=21027),
                    ]),
                  ]
                ) + deployment.pvcVolumeMount(name='%s-config' % $._config.syncthing.name, path='/config')
                + deployment.pvcVolumeMount(name='%s-data' % $._config.syncthing.name, path='/data'),
    smb: deployment.new(
                  name=$._config.syncthing.smbName,
                  replicas=1,
                  containers=[
                    container.new(name=$._config.syncthing.smbName, image=$._config.syncthing.smbImage)
                    + container.withPorts(ports=[
                      containerPort.new(name='smb', port=$._config.syncthing.smbPort),
                    ]),
                  ]
                ) + deployment.pvcVolumeMount(name='%s-data' % $._config.syncthing.name, path='/storage'),
    config: pvc(name='%s-config' % $._config.syncthing.name, size='1Gi'),
    data: pvc(name='%s-data' % $._config.syncthing.name, size=$._config.syncthing.storage),
    syncthingService: serviceFor(deployment=self.syncthing),
    smbService: serviceFor(deployment=self.smb),
    syncthingIngress: tailscale_ingress(
      name=$._config.syncthing.name,
      port=$._config.syncthing.port,
    ),
    smbIngress: tailscale_ingress(
      name=$._config.syncthing.smbName,
      port=$._config.syncthing.smbPort,
    ),
  },

  portainer: {
    deployment: deployment.new(
      name=$._config.portainer.name,
      replicas=1,
      containers=[
        container.new(name=$._config.portainer.name, image=$._config.portainer.image)
        + container.mixin.withPorts(ports=[containerPort.new(name=$._config.portainer.name, port=$._config.portainer.port)]),
      ],
    ) + deployment.pvcVolumeMount(name=$._config.portainer.name, path='/data'),
    data: pvc(name=$._config.portainer.name, size=$._config.portainer.storage),
    service: serviceFor(deployment=self.deployment),
    ingress: tailscale_ingress(
      name=$._config.portainer.name,
      port=$._config.portainer.port,
    ),
  },

  privatebin: {
    deployment: deployment.new(
      name=$._config.privatebin.name,
      replicas=1,
      containers=[
        container.new(name=$._config.privatebin.name, image=$._config.privatebin.image)
        + container.mixin.withPorts(ports=[containerPort.new(name=$._config.privatebin.name, port=$._config.privatebin.port)]),
      ],
    ) + deployment.pvcVolumeMount(name=$._config.privatebin.name, path='/srv/data'),
    data: pvc(name=$._config.privatebin.name, size=$._config.privatebin.storage),
    service: serviceFor(deployment=self.deployment),
    ingress: tailscale_ingress(
      name=$._config.privatebin.name,
      port=$._config.privatebin.port,
      funnel=true,
    ),
  },

  vaultwarden: {
    deployment: deployment.new(
      name=$._config.vaultwarden.name,
      replicas=1,
      containers=[
        container.new(name=$._config.vaultwarden.name, image=$._config.vaultwarden.image)
        + container.mixin.withPorts(ports=[containerPort.new(name=$._config.vaultwarden.name, port=$._config.vaultwarden.port)]),
      ],
    ) + deployment.pvcVolumeMount(name=$._config.vaultwarden.name, path='/data'),
    data: pvc(name=$._config.vaultwarden.name, size=$._config.vaultwarden.storage),
    service: serviceFor(deployment=self.deployment),
    ingress: tailscale_ingress(
      name=$._config.vaultwarden.name,
      port=$._config.vaultwarden.port,
      funnel=true,
    ),
  },

  servarr: {
    jellyfin: deployment.new(
                name='jellyfin',
                replicas=1,
                containers=[
                  container.new(name='jellyfin', image=$._config.servarr.jellyfinImage)
                  + container.mixin.withPorts(ports=[containerPort.new(name='jellyfin', port=$._config.servarr.jellyfinPort)]),
                ],
              ) + deployment.pvcVolumeMount(name='nfs', path='/media')
              + deployment.pvcVolumeMount(name='jellyfin', path='/config', containers=['jellyfin']),
    sonarr: deployment.new(
              name='sonarr',
              replicas=1,
              containers=[
                container.new(name='sonarr', image=$._config.servarr.sonarrImage)
                + container.mixin.withPorts(ports=[containerPort.new(name='sonarr', port=$._config.servarr.sonarrPort)]),
              ],
            ) + deployment.pvcVolumeMount(name='nfs', path='/media')
            + deployment.pvcVolumeMount(name='sonarr', path='/config', containers=['sonarr']),
    qbittorrent: deployment.new(
                   name='qbittorrent',
                   replicas=1,
                   containers=[
                     container.new(name='qbittorrent', image=$._config.servarr.qbittorrentImage)
                     + container.mixin.withPorts(ports=[containerPort.new(name='qbittorrent', port=$._config.servarr.qbittorrentPort)]),
                   ],
                 ) + deployment.pvcVolumeMount(name='nfs', path='/media')
                 + deployment.pvcVolumeMount(name='qbittorrent', path='/config', containers=['qbittorrent']),
    prowlarr: deployment.new(
                name='prowlarr',
                replicas=1,
                containers=[
                  container.new(name='prowlarr', image=$._config.servarr.prowlarrImage)
                  + container.mixin.withPorts(ports=[containerPort.new(name='prowlarr', port=$._config.servarr.prowlarrPort)]),
                ],
              ) + deployment.pvcVolumeMount(name='nfs', path='/media')
              + deployment.pvcVolumeMount(name='prowlarr', path='/config', containers=['prowlarr']),
    radarr: deployment.new(
              name='radarr',
              replicas=1,
              containers=[
                container.new(name='radarr', image=$._config.servarr.radarrImage)
                + container.mixin.withPorts(ports=[containerPort.new(name='radarr', port=$._config.servarr.radarrPort)]),
              ],
            ) + deployment.pvcVolumeMount(name='nfs', path='/media')
            + deployment.pvcVolumeMount(name='radarr', path='/config', containers=['radarr']),
    jellyseerr: deployment.new(
                  name='jellyseerr',
                  replicas=1,
                  containers=[
                    container.new(name='jellyseerr', image=$._config.servarr.jellyseerrImage)
                    + container.mixin.withPorts(ports=[containerPort.new(name='jellyseerr', port=$._config.servarr.jellyseerrPort)]),
                  ],
                ) + deployment.pvcVolumeMount(name='nfs', path='/media')
                + deployment.pvcVolumeMount(name='jellyseerr', path='/app/config', containers=['jellyseerr']),
    flaresolverr: deployment.new(
      name='flaresolverr',
      replicas=1,
      containers=[
        container.new(name='flaresolverr', image=$._config.servarr.flaresolverrImage)
        + container.mixin.withPorts(ports=[containerPort.new(name='flaresolverr', port=$._config.servarr.flaresolverrPort)]),
      ],
    ),
    wizarr: deployment.new(
      name='wizarr',
      replicas=1,
      containers=[
        container.new(name='wizarr', image=$._config.servarr.wizarrImage)
        + container.mixin.withPorts(ports=[containerPort.new(name='wizarr', port=$._config.servarr.wizarrPort)]),
      ],
    ) + deployment.pvcVolumeMount(name='wizarr', path='/data', containers=['wizarr']),
    jellyfinpvc: pvc(name='jellyfin', size=$._config.servarr.jellyfinSize),
    sonarrpvc: pvc(name='sonarr', size=$._config.servarr.sonarrSize),
    qbittorrentpvc: pvc(name='qbittorrent', size=$._config.servarr.qbittorrentSize),
    prowlarrpvc: pvc(name='prowlarr', size=$._config.servarr.prowlarrSize),
    radarrpvc: pvc(name='radarr', size=$._config.servarr.radarrSize),
    jellyseerrpvc: pvc(name='jellyseerr', size=$._config.servarr.jellyseerrSize),
    wizarrpvc: pvc(name='wizarr', size=$._config.servarr.wizarrSize),
    nfsPv: persistentVolume.new(name=$._config.servarr.nfsName)
           + persistentVolume.mixin.spec.nfs.withServer(server=$._config.servarr.nfsServer)
           + persistentVolume.mixin.spec.nfs.withPath(path=$._config.servarr.nfsPath)
           + persistentVolume.mixin.spec.withAccessModes(accessModes=$._config.servarr.nfsAccessModes)
           + persistentVolume.mixin.spec.withStorageClassName(storageClassName='nfs')
           + persistentVolume.mixin.spec.withCapacity(capacity={ storage: $._config.servarr.nfsSize }),
    nfsPvc: persistentVolumeClaim.new(name=$._config.servarr.nfsName)
            + persistentVolumeClaim.mixin.spec.withStorageClassName(storageClassName='nfs')
            + persistentVolumeClaim.mixin.spec.withAccessModes(accessModes=$._config.servarr.nfsAccessModes)
            + persistentVolumeClaim.mixin.spec.resources.withRequests(requests={ storage: $._config.servarr.nfsSize })
            + persistentVolumeClaim.mixin.spec.withVolumeName(volumeName=$._config.servarr.nfsName),
    jellyfinService: serviceFor(deployment=self.jellyfin),
    sonarrService: serviceFor(deployment=self.sonarr),
    qbittorrentService: serviceFor(deployment=self.qbittorrent),
    prowlarrService: serviceFor(deployment=self.prowlarr),
    radarrService: serviceFor(deployment=self.radarr),
    jellyseerrService: serviceFor(deployment=self.jellyseerr),
    flaresolverrService: serviceFor(deployment=self.flaresolverr),
    wizarrService: serviceFor(deployment=self.wizarr),
    ingressJellyfin: tailscale_ingress(name='jellyfin', port=$._config.servarr.jellyfinPort, funnel=true),
    ingressSonarr: tailscale_ingress(name='sonarr', port=$._config.servarr.sonarrPort, funnel=false),
    ingressQbittorrent: tailscale_ingress(name='qbittorrent', port=$._config.servarr.sonarrPort, funnel=false),
    ingressProwlarr: tailscale_ingress(name='prowlarr', port=$._config.servarr.prowlarrPort, funnel=false),
    ingressRadarr: tailscale_ingress(name='radarr', port=$._config.servarr.radarrPort, funnel=false),
    ingressJellyseerr: tailscale_ingress(name='jellyseerr', port=$._config.servarr.jellyseerrPort, funnel=true),
    ingressFlaresolverr: tailscale_ingress(name='flaresolverr', port=$._config.servarr.flaresolverrPort, funnel=false),
    ingressWizarr: tailscale_ingress(name='wizarr', port=$._config.servarr.wizarrPort, funnel=true),
  },

  tandoor: {
    deployment: deployment.new(
      name=$._config.tandoor.name,
      replicas=1,
      containers=[
        container.new(name=$._config.tandoor.name, image=$._config.tandoor.image)
        + container.mixin.withPorts(ports=[containerPort.new(name=$._config.tandoor.name, port=$._config.tandoor.port)]),
      ],
    ) + deployment.pvcVolumeMount(name=$._config.tandoor.name, path='/data'),
    data: pvc(name=$._config.tandoor.name, size=$._config.tandoor.storage),
    service: serviceFor(deployment=self.deployment),
    ingress: tailscale_ingress(
      name=$._config.tandoor.name,
      port=$._config.tandoor.port,
      funnel=true,
    ),
  },
}
