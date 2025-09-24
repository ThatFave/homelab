# k3s tk setup

## install

- `jb update`
- `tk apply environment/k3s.jsonnet`
- pray

## pre uninstall:

```bash
kubectl -n prod patch -p '{"value": "true"}' --type=merge lhs deleting-confirmation-flag
```

## how to:

### secrets

- `kubectl create secret generic tailscale-operator-secret --from-literal=clientId='secret' --from-literal=clientSecret='secret' --dry-run=client -o json > tailscale-operator.json`
- `kubeseal --controller-name=sealedsecrets-sealed-secrets --controller-namespace=prod --namespace=prod --format json < tailscale-operator.json > tailscale-operator.sealed.json`

### update
TODO
