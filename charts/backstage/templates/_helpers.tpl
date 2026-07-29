{{/*
FILE_NAME: _helpers.tpl
DESCRIPTION: Naming and label helpers for Backstage chart
VERSION: 0.1.0
*/}}
{{- define "backstage.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "backstage.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "backstage.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "backstage.labels" -}}
helm.sh/chart: {{ include "backstage.chart" . }}
app.kubernetes.io/name: {{ include "backstage.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ .Values.partOf | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end -}}

{{- define "backstage.selectorLabels" -}}
app.kubernetes.io/name: {{ include "backstage.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "backstage.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "backstage.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "backstage.clusterRoleName" -}}
{{- if .Values.rbac.clusterRoleName -}}
{{- .Values.rbac.clusterRoleName -}}
{{- else -}}
{{- printf "%s-read" (include "backstage.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "backstage.backendName" -}}
{{- printf "%s-backend" (include "backstage.fullname" .) -}}
{{- end -}}

{{- define "backstage.frontendName" -}}
{{- printf "%s-frontend" (include "backstage.fullname" .) -}}
{{- end -}}

{{- define "backstage.configMapName" -}}
{{- printf "%s-app-config" (include "backstage.fullname" .) -}}
{{- end -}}

{{- define "backstage.httpRouteName" -}}
{{- default (include "backstage.fullname" .) .Values.httpRoute.name -}}
{{- end -}}
