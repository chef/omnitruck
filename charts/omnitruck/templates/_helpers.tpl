{{- /*
Create the name of the app
*/}}
{{- define "omnitruck.fullname" -}}
{{- default .Chart.Name .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{- /* 
Labels 
*/}}
{{- define "omnitruck.commonLabels" -}}
{{ include "omnitruck.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ default (include "omnitruck.fullname" .) .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "omnitruck.selectorLabels" -}}
app.kubernetes.io/name: {{ include "omnitruck.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- /*
Create the name of the service account to use
*/}}
{{- define "omnitruck.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "omnitruck.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "omnitruck" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
 https://github.com/helm/helm/issues/4535#issuecomment-477778391
 Usage: {{ include "call-nested" (list . "SUBCHART_NAME" "TEMPLATE") }}
 e.g. {{ include "call-nested" (list . "grafana" "grafana.fullname") }}
*/}}
{{- define "call-nested" }}
{{- $dot := index . 0 }}
{{- $subchart := index . 1 | splitList "." }}
{{- $template := index . 2 }}
{{- $values := $dot.Values }}
{{- range $subchart }}
{{- $values = index $values . }}
{{- end }}
{{- include $template (dict "Chart" (dict "Name" (last $subchart)) "Values" $values "Release" $dot.Release "Capabilities" $dot.Capabilities) }}
{{- end }}

{{/*
Omnitruck container environment variables
*/}}
{{- define "omnitruck.containerEnvironmentVariables" -}}
- name: REDIS_URL
  value: redis://{{ printf "%s-master" (include  "call-nested" (list . "redis" "common.names.fullname")) }}
{{- end }}