{{- /*
Create the name of the app
*/}}
{{- define "omnitruck.fullname" -}}
{{- default .Chart.Name .Values.appName | trunc 63 | trimSuffix "-" }}
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