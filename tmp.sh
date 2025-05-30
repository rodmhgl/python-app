source ./.env

#region install actions-runner-controller
helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
helm repo update

helm upgrade --install --namespace actions-runner-system --create-namespace \
  --set=authSecret.create=true \
  --set=authSecret.github_token=$GH_TOKEN \
  --wait actions-runner-controller actions-runner-controller/actions-runner-controller

kubectl apply -f charts/actions-runner-controller/runnerdeployment.yaml
#endregion

#region run docker for backstage-app
cd /workspaces/python-app/backstage-app/

docker run --rm \
  -e AUTH_GITHUB_CLIENT_ID=$AUTH_GITHUB_CLIENT_ID \
  -e AUTH_GITHUB_CLIENT_SECRET=$AUTH_GITHUB_CLIENT_SECRET \
  -e GITHUB_TOKEN=$GH_TOKEN \
  -e ARGOCD_AUTH_TOKEN='argocd.token=$ARGOCD_AUTH_TOKEN' \
  -p 3000:3000 \
  -p 7007:7007 \
  -ti -v $(pwd):/app \
  -w /app \
  --network backstage \
  rodstewart/test:latest \
  bash

docker run --name backstage \
  -d \
  -e GITHUB_TOKEN=$GH_TOKEN \
  -e AUTH_GITHUB_CLIENT_ID=$AUTH_GITHUB_CLIENT_ID \
  -e AUTH_GITHUB_CLIENT_SECRET=$AUTH_GITHUB_CLIENT_SECRET \
  -p 3000:3000 \
  -p 7007:7007 \
  --network backstage \
  backstage_production

docker run -d \
  --name psql \
  -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
  -e POSTGRES_DB=$POSTGRES_HOST \
  -e POSTGRES_USER=$POSTGRES_USER \
  -e PGDATA=/var/lib/postgresql/data/pgdata \
  -v /tmp/psql:/var/lib/postgresql/data \
  --network backstage \
  postgres:16

yarn build:backend --config ../../app-config.yaml --config ../../app-config.production.yaml 

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install psql bitnami/postgresql --version 15.5.28 -n backstage --create-namespace -f values-postgres.yaml

#endregion