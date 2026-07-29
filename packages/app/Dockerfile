# FILE_NAME: Dockerfile
# DESCRIPTION: Standalone Backstage frontend (static) served by nginx + runtime config inject
# VERSION: 0.2.1
#
# Build from repo root after: yarn install && yarn tsc && yarn workspace app build
#   docker build -f packages/app/Dockerfile -t backstage-frontend .

FROM docker.io/library/nginx:1.27-alpine

RUN apk add --no-cache jq bash python3

COPY packages/app/dist /usr/share/nginx/html
COPY packages/app/docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY packages/app/docker/inject-config.sh /docker-entrypoint.d/40-inject-backstage-config.sh
RUN chmod +x /docker-entrypoint.d/40-inject-backstage-config.sh

EXPOSE 80
