# conduwuit
This is a helm chart for [conduwuit][homepage]

## TL;DR;
```console
helm repo add cronce https://charts.cronce.io/
helm install --set server_name=matrix.example.org cronce/conduwuit
```

## Installing the Chart
To install the chart with the release name `my-release`:

```console
helm install --name my-release cronce/conduwuit
```

## Uninstalling the Chart
To uninstall/delete the `my-release` deployment:

```console
helm delete my-release
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Configuration
The following tables lists the configurable parameters of the conduwuit chart and their default values.

| Parameter                          | Description                                                                                | Default                 |
| ---------------------------------- | ------------------------------------------------------------------------------------------ | ----------------------- |
| `image.repository`                 | Image repository                                                                           | `girlbossceo/conduwuit` |
| `image.tag`                        | Image tag. Possible values listed [here][docker].                                          | `next-commit-147f2752`  |
| `image.pullPolicy`                 | Image pull policy                                                                          | `IfNotPresent`          |
| `config.server_name`               | Server name                                                                                | `your.server.name`      |
| `config.max_request_size`          | Maximum upload size                                                                        | `20000000` (20MB)       |
| `config.allow_registration`        | Whether or not to allow users to register new accounts                                     | `false`                 |
| `config.allow_federation`          | Whether or not to allow federating with other Matrix servers                               | `false`                 |
| `config.trusted_servers`           | Servers to trust when federating; if enabling federating, `matrix.org` usually makes sense | `[]`                    |
| `extraLabels`                      | Additional labels to apply to all created resources                                        | `{}`                    |
| `service.annotations`              | Annotations for Service resource                                                           | `{}`                    |
| `service.type`                     | Type of service to deploy                                                                  | `ClusterIP`             |
| `service.clusterIP`                | ClusterIP of service; if blank, it will be selected at random from the cluster CIDR range  | `None`                  |
| `service.port`                     | Port to expose service                                                                     | `8200`                  |
| `service.externalIPs`              | External IPs for service                                                                   | `[]`                    |
| `service.loadBalancerIP`           | Load balancer IP                                                                           | `""`                    |
| `service.loadBalancerSourceRanges` | List of IP CIDRs allowed to access the load balancer (if supported)                        | `[]`                    |
| `ingress.enabled`                  | Whether or not to deploy the Ingress resource                                              | `false`                 |
| `ingress.class`                    | Ingress class (included in annotations)                                                    | ``                      |
| `ingress.annotations`              | Ingress annotations                                                                        | `{}`                    |
| `ingress.path`                     | Ingress path                                                                               | `/`                     |
| `ingress.hosts`                    | Ingress accepted hostnames                                                                 | `[conduwuit]`           |
| `ingress.tls`                      | Whether or not to configure TLS for the ingerss                                            | `false`                 |
| `persistence.data.enabled`         | Use persistent volume to store data                                                        | `true`                  |
| `persistence.data.size`            | Size of persistent volume claim                                                            | `1Gi`                   |
| `persistence.data.existingClaim`   | Use an existing PVC to persist data                                                        | ``                      |
| `persistence.data.storageClass`    | Type of persistent volume claim                                                            | ``                      |
| `persistence.data.accessMode`      | PVC access mode                                                                            | `ReadWriteMany`         |
| `resources.requests`               | CPU/Memory resource requests                                                               | 1CPU/256MiB             |
| `resources.limits`                 | CPU/Memory resource limits                                                                 | 2CPU/512MiB             |
| `nodeSelector`                     | Node labels for pod assignment                                                             | `{}`                    |
| `tolerations`                      | Toleration labels for pod assignment                                                       | `[]`                    |
| `affinity`                         | Affinity settings for pod assignment                                                       | `{}`                    |

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`. For example,

```console
helm install --name my-release \
	--set ingress.enabled=true \
	cronce/conduwuit
```

Alternatively, a YAML file that specifies the values for the above parameters can be provided while installing the chart. For example,

```console
helm install --name my-release -f values.yaml cronce/conduwuit
```

Read through the [values.yaml](values.yaml) file.

[docker]: https://hub.docker.com/r/girlbossceo/conduwuit
[github]: https://github.com/girlbossceo/conduwuit
[homepage]: https://conduwuit.puppyirl.gay/

