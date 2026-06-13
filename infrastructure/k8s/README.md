# VertexChain Helm Chart

Packages the full VertexChain stack — NestJS backend API, Next.js analytics dashboard, and a PostGIS-enabled PostgreSQL database — into a single installable Helm chart.

## Chart structure

```
infrastructure/k8s/helm/vertexchain/
├── Chart.yaml                   # Chart metadata and dependencies
├── values.yaml                  # Default values (all overridable)
├── README.md                    # This file
└── templates/
    ├── _helpers.tpl              # Shared template helpers
    ├── NOTES.txt                 # Post-install instructions
    ├── serviceaccount.yaml
    ├── backend-configmap.yaml    # Non-sensitive env vars
    ├── backend-secret.yaml       # Sensitive env vars (created when existingSecret is unset)
    ├── backend-deployment.yaml
    ├── backend-service.yaml
    ├── backend-hpa.yaml
    ├── analytics-deployment.yaml
    ├── analytics-service.yaml
    ├── analytics-hpa.yaml
    └── ingress.yaml
```

## Prerequisites

- Kubernetes 1.25+
- Helm 3.10+
- (Optional) [helm-secrets](https://github.com/jkroepke/helm-secrets) for encrypted values

## Quick start

```bash
# 1. Add the Bitnami repo (required for PostgreSQL sub-chart)
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# 2. Fetch sub-chart dependencies
helm dependency update ./infrastructure/k8s/helm/vertexchain

# 3. Install to the vertexchain namespace
helm upgrade --install vertexchain ./infrastructure/k8s/helm/vertexchain \
  --namespace vertexchain --create-namespace \
  --set backend.image.tag=sha-<commit>
```

## Configuration

All values are documented inline in `values.yaml`. The most commonly overridden keys are:

| Key | Default | Description |
|-----|---------|-------------|
| `backend.image.tag` | `.Chart.AppVersion` | Docker image tag — set to the CI-produced SHA tag |
| `backend.replicaCount` | `2` | Number of backend pods |
| `backend.env.SOROBAN_RPC_URL` | testnet URL | Soroban RPC endpoint |
| `backend.env.CONTRACT_ID_GIST_REGISTRY` | `""` | Deployed contract ID |
| `backend.env.CORS_ORIGINS` | `""` | Comma-separated allowed origins |
| `backend.secrets.DATABASE_PASSWORD` | `changeme` | **Override in production** |
| `backend.secrets.STELLAR_SECRET_KEY` | `""` | Backend signing keypair |
| `backend.existingSecret` | `""` | Use a pre-existing Secret instead |
| `analytics.image.tag` | `.Chart.AppVersion` | Analytics image tag |
| `analytics.env.NEXT_PUBLIC_API_URL` | `""` | Backend URL exposed to the browser |
| `ingress.enabled` | `false` | Enable Ingress resource |
| `ingress.hosts` | see values | Host rules for backend and analytics |
| `postgresql.enabled` | `true` | Deploy bundled PostgreSQL (PostGIS) |
| `postgresql.auth.password` | `changeme` | **Override in production** |

## Environment-specific overrides

Create a thin override file per environment:

```yaml
# values.prod.yaml
backend:
  replicaCount: 3
  image:
    tag: sha-a1b2c3d
  env:
    NODE_ENV: production
    SOROBAN_RPC_URL: https://soroban-mainnet.stellar.org
    STELLAR_NETWORK_PASSPHRASE: "Public Global Stellar Network ; September 2015"
    CONTRACT_ID_GIST_REGISTRY: "CXXXX..."
    CORS_ORIGINS: "https://app.vertexchain.io"
  existingSecret: vertexchain-backend-secret   # managed by external-secrets

analytics:
  replicaCount: 2
  env:
    NEXT_PUBLIC_API_URL: https://api.vertexchain.io

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  tls:
    - secretName: vertexchain-tls
      hosts:
        - api.vertexchain.io
        - analytics.vertexchain.io

postgresql:
  enabled: false   # use a managed database in production
```

Then install with:

```bash
helm upgrade --install vertexchain ./infrastructure/k8s/helm/vertexchain \
  --namespace vertexchain --create-namespace \
  -f values.prod.yaml
```

## Managing secrets

For production, avoid putting plaintext passwords in values files. Options:

1. **`existingSecret`** — pre-create the Secret via CI/external-secrets and point `backend.existingSecret` at it. The chart skips creating its own Secret.
2. **[helm-secrets](https://github.com/jkroepke/helm-secrets)** — encrypt a `values.secrets.yaml` with SOPS and pass it with `-f`.
3. **External Secrets Operator** — sync secrets from AWS Secrets Manager / Vault into the cluster.

## Upgrading the chart

```bash
# Bump chart version in Chart.yaml, then:
helm upgrade vertexchain ./infrastructure/k8s/helm/vertexchain \
  --namespace vertexchain \
  --set backend.image.tag=sha-<new-commit>
```

## Rollback

```bash
helm history vertexchain -n vertexchain
helm rollback vertexchain <revision> -n vertexchain
```

## Uninstall

```bash
helm uninstall vertexchain -n vertexchain
# PVCs are NOT deleted automatically; remove manually if needed:
kubectl delete pvc -n vertexchain -l app.kubernetes.io/instance=vertexchain
```