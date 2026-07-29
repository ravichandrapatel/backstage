# DevZero Backstage

Split **frontend** (nginx static) and **backend** (Node) images, with:

| Plugin | Package |
| --- | --- |
| Kubernetes (official) | `@backstage/plugin-kubernetes` + `-backend` |
| Argo CD | `@roadiehq/backstage-plugin-argo-cd` + `-backend` |
| Kyverno Policy Reporter (official) | `@kyverno/backstage-plugin-policy-reporter` + `-backend` |
| Tekton Pipelines | `@backstage-community/plugin-tekton` (via Kubernetes backend) |

## Local (Node 22+)

```bash
nvm use 22
yarn install
yarn start          # frontend :3000 + backend :7007
# or separately:
yarn workspace app start
yarn workspace backend start
```

## Build & push images (Gitea registry only)

```bash
./scripts/build-push-gitea.sh
```

Images:

- `gitea.devzero.local:8443/giteaadmin/backstage-frontend:<tag|latest>`
- `gitea.devzero.local:8443/giteaadmin/backstage-backend:<tag|latest>`

Push uses `crane` + lab CA (`clusters/lab/certs/ca.crt`); registry path owner is lowercase `giteaadmin`.

Production env for backend: `APP_BASE_URL`, `BACKEND_BASE_URL`, `POSTGRES_*`, `ARGOCD_*`.
