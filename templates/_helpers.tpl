{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "php-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "php-app.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "php-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create basic auth for ingress
*/}}
{{- define "php-app.basic-auth" -}}
{{- if .Values.auth.enabled -}}
{{- range $key, $value := .Values.auth.users -}}
{{ $key }}:{PLAIN}{{ $value }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create nginx configs
*/}}
{{- define "php-app.nginx-configs" -}}
{{- $type := .Values.type -}}
{{- if .Values.nginx.configs -}}
{{ toYaml .Values.nginx.configs }}
{{- else -}}
{{- if (eq $type "symfony") -}}
{{ toYaml .Values.default.symfony.nginx.configs }}
{{- end -}}
{{- if (eq $type "laravel") -}}
{{ toYaml .Values.default.laravel.nginx.configs }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create job template
*/}}
{{- define "php-app.job-template" -}}
{{- if .Values.jobs.enabled }}
{{- $fullName := include "php-app.fullname" . -}}
{{- $name := include "php-app.name" . -}}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ $name }}-
  namespace: {{ .Release.Namespace }}
  labels:
    app.kubernetes.io/name: {{ $name }}-
    helm.sh/chart: {{ include "php-app.chart" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
    app.kubernetes.io/managed-by: {{ .Release.Service }}
spec:
  activeDeadlineSeconds: {{ .Values.jobs.activeDeadlineSeconds | default 10 }}
  ttlSecondsAfterFinished: {{ .Values.jobs.ttlSecondsAfterFinished | default 10 }}
  template:
    spec:
      restartPolicy: {{ .Values.jobs.restartPolicy | default "OnFailure" }}
    {{- if .Values.configs }}
      volumes:
        - name: app-configs
          configMap:
            name: {{ $fullName }}-configs
    {{- end }}
      containers:
        - name: job
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          command:
            - docker-php-entrypoint
          args:
            - php
            - -v
        {{- if or .Values.env.secret .Values.env.open }}
          envFrom:
          {{- if .Values.env.secret }}
            - secretRef:
                name: {{ $fullName }}
          {{- end }}
          {{- if .Values.env.open }}
            - configMapRef:
                name: {{ $fullName }}
          {{- end }}
        {{- end }}
        {{- if .Values.configs }}
          volumeMounts:
          {{- range $idx, $cfg := .Values.configs }}
            - name: app-configs
              mountPath: {{ $cfg.path }}
              subPath: {{ $cfg.name }}
              readOnly: true
          {{- end }}
        {{- end }}
          resources:
{{ toYaml (default .Values.resources .Values.jobs.resources) | indent 12 }}
{{- with (default .Values.nodeSelector .Values.jobs.nodeSelector) }}
      nodeSelector:
{{ toYaml . | indent 12 }}
{{- end }}
{{- with (default .Values.affinity .Values.jobs.affinity) }}
      affinity:
{{ toYaml . | indent 12 }}
{{- end }}
{{- with (default .Values.tolerations .Values.jobs.tolerations) }}
      tolerations:
{{ toYaml . | indent 12 }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
Create service account
*/}}
{{- define "php-app.service-account" -}}
{{- if .Values.rbac.enabled -}}
{{ template "php-app.fullname" . }}
{{- else -}}
default
{{- end -}}
{{- end -}}

{{/*
Create rbac rules
*/}}
{{- define "php-app.rbac-rules" -}}
{{- if .Values.rbac.enabled -}}
{{ default .Values.default.rbac.rules .Values.rbac.rules | toYaml }}
{{- end -}}
{{- end -}}