#!/usr/bin/env bash
#
# =============================================================================
#  k3s-dashboard-token.sh
#  获取 K8s Dashboard 的登录 Token（Bearer Token）
# =============================================================================
#
#  ██ 这个脚本是干什么的 ██
#  --------------------------------------------------------------------------
#  Kubernetes Dashboard 是跑在 k3s 集群里的一个 Web 管理后台（类似一个
#  "管理控制台"Web 应用）。要登录它，不能像普通网站那样输用户名密码，
#  而是要把一串 Token（一段 JWT 风格的字符串）粘贴到登录框里。
#
#  本脚本的作用，就是让集群帮你生成这串 Token 并打印到屏幕上，
#  你把打印出来的字符串复制粘贴到 Dashboard 登录页即可。
#
#  ██ 给 Java 工程师的原理说明 ██
#  --------------------------------------------------------------------------
#  整条命令可以拆成三层看，从外到内：
#
#  ① ssh george@192.168.31.192 '...'
#     └─ 类比：你远程登录到一台服务器（华硕，Ubuntu），在它的 shell 上执行
#        后面单引号里的命令。相当于"连到生产机上去操作"。
#
#  ② sudo k3s kubectl ...
#     └─ kubectl 是 Kubernetes 的命令行客户端，类比 MySQL 的 mysql CLI 客户端。
#        它通过 HTTPS 调用 kube-apiserver（K8s 的唯一入口，类比网关/Controller）
#        来请求集群状态。
#        k3s 是 Rancher 出的轻量级 K8s 发行版，把 k8s 打成一个二进制，
#        "k3s kubectl" 等价于直接用 kubectl，只是换了个封装入口。
#        sudo 是因为读取/签发集群凭据需要 root 权限。
#
#  ③ kubectl create token admin-dashboard
#     └─ 语义：让集群为名为 "admin-dashboard" 的 ServiceAccount 签发一个
#        短期有效的 Token。
#        - ServiceAccount：K8s 里的"服务账号"，类比代码里的一个带权限的角色
#          （本仓库中该账号被绑定了 cluster-admin，即集群最高权限，
#          可见 scripts/../infrastructure/eks 之外的部署说明）。
#        - Token 是 JWT 格式（看打印结果开头 eyJhbGciOi... 就是 Base64 编码的
#          JWT Header），类比你们 Java 微服务里签发的 JWT：都带签名、
#          都含过期时间（exp 字段），服务端验签后决定放不放行。
#        - "create token" 每次生成的都是**新的、有时效**的 Token（默认约 1 小时），
#          而不是读取长期存在的 Secret。这是较新的推荐做法，
#          类比用"签发临时凭证"而不是"共享一把永久钥匙"。
#
#  ██ 为什么集群能"认证"这个 Token ██
#  --------------------------------------------------------------------------
#  Dashboard 拿到 Token 后，把它塞进 HTTP 请求的 Authorization: Bearer <token>
#  头里发给 kube-apiserver（类比网关校验 JWT）。apiserver 验签通过后，
#  就按 Token 对应的 ServiceAccount 权限放行——因为是 cluster-admin，
#  所以能看/操作整个集群的资源。
#
#  ██ 使用方式 ██
#  --------------------------------------------------------------------------
#    $ ./k3s-dashboard-token.sh
#    eyJhbGciOiJSUzI1NiIsImtpZCI6...（一长串，复制它）
#    然后打开 http://127.0.0.1:8001/.../https:kubernetes-dashboard:/proxy/
#    粘贴 Token 登录。
#
#  ██ 常见问题 ██
#  --------------------------------------------------------------------------
#  1. Token 过期了（登录提示 Unauthorized）？
#     重新跑一次本脚本即可，每次都是新 Token。
#  2. 想改账号？改下面 SERVER_HOST / NAMESPACE / SA_NAME 三个变量。
#  3. 这台 Mac 到服务器是免密 SSH（~/.ssh/config 已配置），所以能直接跑通。
# =============================================================================

set -e

# ---- 可配置项（按需修改） ----
SERVER_HOST="george@192.168.31.192"   # 华硕服务器：SSH 登录名@内网IP
NAMESPACE="kubernetes-dashboard"      # Dashboard 所在的 K8s 命名空间
SA_NAME="admin-dashboard"             # 管理员 ServiceAccount 名称

# ---- 生成并打印 Token ----
# 远程在服务器上执行 k3s kubectl，让集群签发 Token，
# 把结果存进变量，再打印出来方便复制。
TOKEN=$(ssh "$SERVER_HOST" "sudo k3s kubectl -n $NAMESPACE create token $SA_NAME")

echo "=== Kubernetes Dashboard 登录 Token ==="
echo "$TOKEN"
echo "========================================"
echo "复制上面这串 Token，粘贴到 Dashboard 登录页的 Token 输入框即可。"
