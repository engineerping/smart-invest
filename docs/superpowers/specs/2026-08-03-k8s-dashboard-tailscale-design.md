# K3S Kubernetes Dashboard 可视化（Tailscale 访问）设计

> 日期：2026-08-03
> 背景：ASUS 服务器（Ubuntu 24.04，主机名 georgeserver，内网 192.168.31.192）运行 k3s 单节点集群。
> 需求：从 Mac 通过 Web 浏览器查看/管理 K3S 集群的可视化界面。
> 访问方式：通过服务器上的 Tailscale 组网，从公网/任意地方接入，全程加密隧道。

## 1. 目标与决策

- 形态：浏览器访问的 Web 界面（Kubernetes Dashboard）。
- 访问通道：Tailscale 组网（组网型内网穿透），不向公网暴露任何真实端口。
- 工具选型：**Kubernetes Dashboard**（官方），理由：
  - 轻量（一个 Deployment + metrics-scraper），资源占用小，适合单节点学习/运维场景。
  - 界面直接对应 K8s 原生对象（Deployment/Service/Pod/Ingress），对学习 K8s 概念最贴近。
  - k3s 官方推荐，与 k3s 兼容性最佳。
  - 排除 Rancher（较重，多集群/用户体系当前用不上）与 KubeSphere（组件最多，明显过度）。

## 2. 架构

```
你的 Mac（任何地方，公网也行）
├── Tailscale 客户端 ──► ASUS 服务器 (tailnet IP 100.x.x.x)
│                        └── k3s server :6443 (kube-apiserver)
│                            └── kubernetes-dashboard 命名空间
│                                ├── dashboard Deployment + Pod
│                                ├── dashboard Service (ClusterIP，仅集群内可达)
│                                └── metrics-scraper (CPU/内存图表数据源)
└── kubectl proxy（本地 :8001） ──► http://localhost:8001 ──► Mac 浏览器
```

关键点：

1. 服务器上只新增一个 dashboard（官方 `recommended.yaml`，含 dashboard + metrics-scraper）。
   k3s 自带的 metrics-server 直接复用，不需要额外安装。
2. dashboard 的 Service 保持 **ClusterIP**：不建 NodePort、不做 Ingress、不映射给穿透软件。
   它在集群内部，只有 kube-apiserver 能代理到它。
3. Mac 上的 `kubectl proxy` 是访问通道：本地监听 `localhost:8001`，
   请求经 Tailscale 隧道发往 ASUS 的 6443，再由 apiserver 转发给 dashboard 服务。
   浏览器全程只看到 `http://localhost:8001`。

## 3. 安全模型

核心原则：**dashboard 不设密码，登录方式 = K8s 集群的身份认证（ServiceAccount Token）**。

```
浏览器 ─► localhost:8001 ─► kubectl proxy ─► apiserver :6443
                                               │ 浏览器访问 dashboard 页面
                                               │ dashboard 要求 token 登录
                                               │ 粘贴管理员 SA 的 token
                                               ▼
                                          认证通过 ─► 读取集群状态
```

- Tailscale 只负责"能到达这台机器"，不负责"你是谁"；组网内设备互信，
  任何一台设备上的人都能触达 6443。Token 是第二道门。
- dashboard 通过 `kubectl proxy` 访问时走 apiserver 的 HTTPS 隧道，无需额外处理证书。

### 登录流程

1. 在 ASUS 服务器上创建管理员 ServiceAccount 并绑定集群管理员权限：
   ```bash
   kubectl create serviceaccount admin-dashboard -n kubernetes-dashboard
   kubectl create clusterrolebinding admin-dashboard \
     --clusterrole=cluster-admin \
     --serviceaccount=kubernetes-dashboard:admin-dashboard
   ```
2. 取出该 SA 的 token，粘贴到浏览器登录框。token 在集群证书有效期内长期有效，
   可存入 Mac 钥匙串，无需每次重新生成。

## 4. 部署与验证清单

### 部署（ASUS 服务器）

```bash
# 1. 部署 dashboard（官方清单）
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v3.0.0-alpha0/aio/deploy/recommended.yaml

# 2. 创建管理员 SA + 绑定
kubectl create serviceaccount admin-dashboard -n kubernetes-dashboard
kubectl create clusterrolebinding admin-dashboard \
  --clusterrole=cluster-admin \
  --serviceaccount=kubernetes-dashboard:admin-dashboard
```

### Mac 端准备

```bash
# 3. 获取 k3s kubeconfig 并改为 Tailscale IP
scp george@<ASUS内网IP>:~/.kube/config ~/.kube/config-asus
#   编辑 ~/.kube/config-asus，把 server 字段的 127.0.0.1 改为 Tailscale IP (100.x.x.x)

export KUBECONFIG=~/.kube/config-asus
kubectl get nodes   # 应列出华硕节点

# 4. 启动代理
kubectl proxy

# 5. 浏览器访问（dashboard 的 https 服务经 proxy 转发）
#    http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

### 验证清单

| # | 检查项 | 通过标准 |
|---|---|---|
| 1 | 部署后 Pod 状态 | dashboard 容器 Running，metrics-scraper Running |
| 2 | kubeconfig 从 Mac 连通 | `kubectl get nodes` 列出华硕节点 |
| 3 | proxy 页面 | 浏览器打开 URL 能加载登录页 |
| 4 | token 登录 | 粘贴 admin-dashboard token 进入主界面 |
| 5 | 真实数据 | Pod/Deployment 列表有内容，图表有数据（metrics-scraper 生效） |

## 5. 已知风险与对策

| 风险 | 对策 |
|---|---|
| dashboard v3 默认要求 HTTPS | `kubectl proxy` 走 apiserver 的 HTTPS 隧道，通常可绕开 |
| 镜像拉取慢/超时 | 已确认华硕现在能正常拉镜像；若个别镜像仍慢，可用 crane 拉取 + `k3s ctr images import` 手动导入（见 doc-K8S/0.1.k8s-manual-install-notes.md 第 9 节） |
| kubeconfig 指向 127.0.0.1 | 从 Mac 连必须改为 Tailscale IP，否则 proxy 连不上 |
