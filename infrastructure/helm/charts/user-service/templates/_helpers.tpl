{{/*
  ╔═══════════════════════════════════════════════════════════════════════════╗
  ║  🧩 _helpers.tpl —— Helm 的「公共函数库」, 类比 Java 的 @UtilityClass  ║
  ╚═══════════════════════════════════════════════════════════════════════════╝

  📖 这个文件在 Helm 工作流中的位置:
    Helm 加载 templates/ 目录时, 先处理 _helpers.tpl (因为 _ 开头 → 不输出 YAML),
    然后其他 .yaml 模板调用 {{ include "svc.fullname" . }} 来复用这里定义的逻辑。

    _ 开头 = Helm 约定: 这个文件只包含「命名模板」(define 块),
    不产生 K8S 资源, 不会被渲染成实际的 YAML 输出。
    类比: Java 的 interface + default method, 或 abstract class

  📖 Go Template 语法快览 (在代码里逐行注释):
    {{ define "名字" }} ... {{ end }}  → 定义一个命名模板 (函数)
    {{-   → 去掉左边的空白 (让输出的 YAML 更整齐)
    -}}   → 去掉右边的空白
    .     → 根上下文 (当前作用域的点, 包含 .Values .Release .Chart 等)
    $var  → 局部变量
    |     → 管道操作符: 左边输出 → 右边函数输入 (类比 Java Stream 的 map)
    trunc N | trimSuffix "-" → 截断超过 N 字符, 去掉末尾的 "-"

  📖 引用的内置对象 (Helm 模板引擎注入):
    模板中 . 开头的都是 Helm 在渲染前注入的「内置对象」:
      .Chart     → Chart.yaml 的内容 (如 .Chart.Name = "user-service")
      .Release   → 当前 Release 信息 (如 .Release.Name = "smart-invest")
      .Values    → values.yaml 合并后的所有值
      .Template  → 当前模板文件的元信息 (Name, BasePath)
      .Capabilities → K8S 集群的版本和能力
      .Files     → chart 内的非模板文件内容
*/}}

{{/*
  ═════════════════════════════════════════════════════════════════════════════
  define "svc.name" —— 生成资源的短名称
  ═════════════════════════════════════════════════════════════════════════════
  逻辑:
    1. 如果 values.yaml 里写了 nameOverride → 用它
    2. 如果没写 → 用 Chart.yaml 里的 .Chart.Name
    3. 截断到 63 字符 (K8S 资源名最长 63 字符), 去掉末尾的 "-"
  渲染结果: "user-service"
*/}}
{{- define "svc.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
  ═════════════════════════════════════════════════════════════════════════════
  define "svc.fullname" —— 生成资源的全限定名
  ═════════════════════════════════════════════════════════════════════════════
  逻辑 (优先级从高到低):
    1. 如果 values 里写了 fullnameOverride → 直接用 (如 umbrella 覆写为 "user-service")
    2. 如果 Release 名已经包含了 chart 名 → 直接返回 Release 名
    3. 否则 → Release名-Chart名 (如 smart-invest-user-service, 再截断到 63 字符)
  渲染结果: "user-service" (因为 umbrella chart 里设置了 fullnameOverride)
*/}}
{{- define "svc.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
  ═════════════════════════════════════════════════════════════════════════════
  define "svc.labels" —— 生成 K8S 推荐标签 (Recommended Labels)
  ═════════════════════════════════════════════════════════════════════════════
  这些标签贴在所有资源上, 用来:
    1. Service 的 selector 匹配 Pod 的 label → 实现服务发现
    2. Prometheus 按 label 聚合监控指标
    3. helm list / kubectl get 按 label 过滤资源

  K8S 推荐标签标准 (kubernetes.io 命名空间):
    app.kubernetes.io/name:       应用名
    app.kubernetes.io/instance:   Release 实例名 (同一 chart 可以装多次)
    app.kubernetes.io/version:    应用的版本号
    app.kubernetes.io/managed-by: 管理工具 (Helm 部署就写 Helm)

  类比 Java: @Component 注解的 name 属性 —— 给资源打标记, 便于查找和关联
*/}}
{{- define "svc.labels" -}}
app.kubernetes.io/name: {{ include "svc.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

