import { createApp } from '@backstage/frontend-defaults';
import catalogPlugin from '@backstage/plugin-catalog/alpha';
import kubernetesPlugin from '@backstage/plugin-kubernetes/alpha';
import argoCdPlugin from '@roadiehq/backstage-plugin-argo-cd/alpha';
import policyReporterPlugin from '@kyverno/backstage-plugin-policy-reporter/alpha';
import tektonPlugin from '@backstage-community/plugin-tekton/alpha';
import { authModule } from './modules/auth';
import { navModule } from './modules/nav';

export default createApp({
  features: [
    catalogPlugin,
    kubernetesPlugin,
    argoCdPlugin,
    policyReporterPlugin,
    tektonPlugin,
    authModule,
    navModule,
  ],
});
