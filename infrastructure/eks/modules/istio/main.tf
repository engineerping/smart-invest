# =============================================================================
# Istio 服务网格模块
# =============================================================================
# Istio 是一个 Service Mesh（服务网格），通过在 Pod 旁边注入一个 Sidecar
# 代理（Envoy），在基础设施层面统一处理服务间的通信逻辑。
#
# 核心概念：
#   - Sidecar Proxy (Envoy)：每个 Pod 里多跑一个边车容器，代理所有流量
#   - Control Plane (Istiod)：控制面，负责下发配置给所有 Envoy
#   - VirtualService：流量路由规则（例如：10% 流量到 v2 版本）
#   - DestinationRule：目标服务策略（例如：熔断、负载均衡算法）
#   - Gateway：入口网关，类似 K8s Ingress 但更强
#
# 为什么要在架构设计中选择 Istio：
#   1. 熔断/重试/超时从 Java 代码（Resilience4j）下沉到基础设施层
#      好处：业务代码更干净，非业务关注点由 infra 层统一管理
#   2. 流量管理：灰度发布、A/B 测试不需要改代码
#   3. 可观测性：自动生成 Metrics、Traces、Logs，无需埋点
#   4. 安全：Pod 间 mTLS 加密通信，银行级安全要求

resource "helm_release" "istio_base" {
  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  namespace  = "istio-system"
  version    = "1.20.0"  # 固定版本，保证可复现

  create_namespace = true  # 如果 namespace 不存在则自动创建

  # Helm Chart 的自定义参数
  # values 等同于在命令行中传递的 --set 参数
  set {
    name  = "defaultRevision"
    value = "default"
  }
}

resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  namespace  = "istio-system"
  version    = "1.20.0"

  depends_on = [helm_release.istio_base]  # 必须先装 base chart

  # Istio 控制面的配置
  set {
    name  = "meshConfig.accessLogFile"
    value = "/dev/stdout"  # 访问日志输出到标准输出，方便 CloudWatch 采集
  }

  set {
    name  = "meshConfig.enableTracing"
    value = "true"  # 启用分布式追踪（结合 AWS X-Ray）
  }

  # Pilot（Istio 的核心组件，负责服务发现和配置下发）的资源限制
  set {
    name  = "pilot.resources.requests.cpu"
    value = "500m"
  }
  set {
    name  = "pilot.resources.requests.memory"
    value = "2048Mi"
  }
}

# =============================================================================
# Istio Gateway (入口网关)
# =============================================================================
# Ingress Gateway 是进入服务网格的大门
# 所有外部流量先经过 Ingress Gateway → VirtualService → 目标服务
resource "helm_release" "istio_ingress" {
  name       = "istio-ingressgateway"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  namespace  = "istio-system"
  version    = "1.20.0"

  depends_on = [helm_release.istiod]

  set {
    name  = "service.type"
    value = "NodePort"  # 先暴露为 NodePort，然后通过 NLB 接入
    # NodePort 在 30000-32767 之间分配端口
  }

  # 设置端口映射
  values = [
    <<-EOT
    service:
      ports:
        - name: status-port
          port: 15021
          targetPort: 15021
        - name: http2
          port: 80
          targetPort: 8080
        - name: https
          port: 443
          targetPort: 8443
    EOT
  ]
}

# =============================================================================
# 以下是 K8s 层面的 Istio 配置（通过 kubectl manifest 部署）
# 这些配置定义了服务网格的流量规则
# =============================================================================

# Istio Gateway 配置 —— 定义入口流量规则
resource "kubectl_manifest" "istio_gateway" {
  depends_on = [helm_release.istio_ingress]

  yaml_body = <<-YAML
    apiVersion: networking.istio.io/v1beta1
    kind: Gateway
    metadata:
      name: smart-invest-gateway
      namespace: istio-system
    spec:
      selector:
        istio: ingressgateway  # 选择刚才部署的 ingress gateway Pod
      servers:
        - port:
            number: 80
            name: http
            protocol: HTTP
          hosts:
            - "${var.domain_name}"
          # HTTP → HTTPS 重定向
          tls:
            httpsRedirect: true
        - port:
            number: 443
            name: https
            protocol: HTTPS
          hosts:
            - "${var.domain_name}"
          tls:
            mode: SIMPLE           # 标准的 TLS 终止
            credentialName: smart-invest-tls  # 引用 K8s Secret 中的证书
  YAML
}

# VirtualService —— 将流量路由到具体的微服务
# 这里演示了基础的流量路由，实际可以通过 Istio CRD 实现金丝雀发布
resource "kubectl_manifest" "virtual_service_user" {
  depends_on = [kubectl_manifest.istio_gateway]

  yaml_body = <<-YAML
    apiVersion: networking.istio.io/v1beta1
    kind: VirtualService
    metadata:
      name: user-service-vs
      namespace: smart-invest
    spec:
      hosts:
        - "${var.domain_name}"
      gateways:
        - istio-system/smart-invest-gateway
      http:
        # 用户相关 API 路由到 user-service
        - match:
            - uri:
                prefix: "/api/users"
          route:
            - destination:
                host: user-service.smart-invest.svc.cluster.local
                port:
                  number: 8080
          # 配置超时时间（替代 Java 代码中的超时设置）
          timeout: 30s
          # 配置重试策略（替代 Java 代码中的 Resilience4j）
          retries:
            attempts: 3
            perTryTimeout: 5s
            retryOn: "5xx,connect-failure,refused-stream"
  YAML
}

# DestinationRule —— 为服务配置熔断策略
resource "kubectl_manifest" "destination_rule_user" {
  depends_on = [kubectl_manifest.virtual_service_user]

  yaml_body = <<-YAML
    apiVersion: networking.istio.io/v1beta1
    kind: DestinationRule
    metadata:
      name: user-service-dr
      namespace: smart-invest
    spec:
      host: user-service.smart-invest.svc.cluster.local
      # 熔断策略（替代 Java 代码中的 Resilience4j CircuitBreaker）
      trafficPolicy:
        connectionPool:
          tcp:
            maxConnections: 100          # 最大连接数
            connectTimeout: 5s           # 连接超时
          http:
            http1MaxPendingRequests: 50  # 最大排队请求
            maxRequestsPerConnection: 10 # 每个连接最大请求
        outlierDetection:                 # 异常检测（熔断触发条件）
          consecutive5xxErrors: 5        # 连续 5 次 5xx 错误则熔断
          interval: 30s                  # 每 30 秒扫描一次
          baseEjectionTime: 60s          # 熔断后 60 秒再尝试恢复
          maxEjectionPercent: 50         # 最多熔断 50% 的实例
  YAML
}
