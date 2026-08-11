# Helm 常用命令速查手册
# Helm Common Commands Reference

> 基于 Helm 3 版本。所有示例以 smart-invest 项目为上下文。
> Based on Helm 3. All examples use the smart-invest project context.

---

## 一、安装与基础操作 / Install & Basic Operations

### 1. `helm install` — 安装一个新的 Release

```bash
helm install <release-name> <chart-path> [flags]
```

| 参数 | 作用 | 示例 |
|------|------|------|
| `<release-name>` | 给这次部署起的名字（Helm 里叫 Release），后续所有操作都用这个名字 | `smart-invest` |
| `<chart-path>` | Chart 的路径（本地目录、.tgz 包、或 repo URL） | `./umbrella` |
| `-n, --namespace` | 部署到哪个 K8s namespace | `-n smart-invest` |
| `--create-namespace` | namespace 不存在时自动创建 | `--create-namespace` |
| `-f, --values` | 指定额外的 values 文件（可多次使用，后覆盖前） | `-f values-prod.yaml` |
| `--set` | 命令行覆盖单个值（最高优先级） | `--set user-service.image.tag=v2` |
| `--wait` | 等所有 Pod 都 Ready 后才返回，超时则失败 | `--wait` |
| `--timeout` | 等待超时时间（配合 `--wait` 使用） | `--timeout 300s` |
| `--dry-run` | 只渲染模板不真正部署（检查生成的 YAML 是否正确） | `--dry-run` |
| `--debug` | 打印详细输出，方便排查模板渲染错误 | `--debug` |
| `--atomic` | 部署失败时自动回滚到上一个版本 | `--atomic` |
| `--dependency-update` | 自动 `helm dependency update`（更新 chart 依赖） | `--dependency-update` |

**我的项目实际用法：**
```bash
helm install smart-invest ./umbrella \
  --namespace smart-invest --create-namespace \
  -f values-dev.yaml \
  --wait --timeout 300s
```

---

### 2. `helm upgrade --install` — 升级或首次安装（最常用！）

```bash
helm upgrade --install <release-name> <chart-path> [flags]
```

| 参数 | 作用 |
|------|------|
| `--install` | **如果 Release 不存在，自动转为安装；存在则升级**。这是工业标准用法，避免「release not found」报错 |
| `-n, --namespace` | 指定 namespace |
| `--create-namespace` | namespace 不存在时自动创建 |
| `--set` | 覆盖 values |
| `-f, --values` | 额外的 values 文件 |
| `--wait` | 等待所有 Pod 就绪 |
| `--timeout` | 超时时间 |
| `--atomic` | 升级失败自动回滚 |
| `--force` | 强制重建资源（当 K8s 资源被手动改过时很有用） |
| `--reset-values` | 重置为 chart 默认 values（清空之前 `--set` 的值） |
| `--reuse-values` | 保留上一次部署的 `--set` 值（不重置） |
| `--dry-run` | 预览将要变更的内容，不实际执行 |
| `--debug` | 详细输出 |

**我的项目实际用法（[deploy-k3s.sh](scripts/deploy-k3s.sh)）：**
```bash
sudo helm upgrade --install smart-invest . \
  --namespace smart-invest --create-namespace \
  --set user-service.image.tag=v1 \
  --set fund-service.image.tag=v1 \
  --wait --timeout 300s
```

**面试高频考点：** 面试官会问「helm upgrade 遇到 release not found 怎么办？」→ 加 `--install`。

---

## 二、查看与查询 / Inspect & Query

### 3. `helm list` — 列出所有 Release

```bash
helm list [flags]
```

| 参数 | 作用 |
|------|------|
| `-n, --namespace` | 只看指定 namespace | `-n smart-invest` |
| `-A, --all-namespaces` | 看所有 namespace | `-A` |
| `-a, --all` | 显示所有状态的 release（包括已删除的） | `-a` |
| `-d, --date` | 按日期排序 | `-d` |
| `-q, --short` | 只显示 release 名字 | `-q` |
| `-o, --output` | 输出格式：`table`（默认）/ `json` / `yaml` | `-o json` |

**输出示例：**
```
NAME            NAMESPACE       REVISION    STATUS      CHART                   APP VERSION
smart-invest    smart-invest    8           deployed    smart-invest-0.1.0      1.0.0
```

---

### 4. `helm status` — 查看 Release 当前状态

```bash
helm status <release-name> [flags]
```

| 参数 | 作用 |
|------|------|
| `-n, --namespace` | 指定 namespace |
| `--show-resources` | 列出该 release 管理的所有 K8s 资源 |
| `-o, --output` | 输出格式：`table` / `json` / `yaml` |

**用途：** 部署后确认状态、查看当前版本号（revision）、部署时间、和 NOTES 信息。

**我的项目：**
```bash
helm status smart-invest -n smart-invest
```

---

### 5. `helm history` — 查看部署历史（回滚前必看！）

```bash
helm history <release-name> [flags]
```

| 参数 | 作用 |
|------|------|
| `-n, --namespace` | 指定 namespace |
| `--max` | 最多显示多少条记录 | `--max 10` |
| `-o, --output` | 输出格式：`table` / `json` / `yaml` |

**输出示例：**
```
REVISION  UPDATED                  STATUS          CHART               DESCRIPTION
1         Mon Aug 4 10:00:00 2026  deployed        smart-invest-0.1.0  Install complete
2         Mon Aug 4 14:00:00 2026  deployed        smart-invest-0.1.0  Upgrade complete
3         Tue Aug 5 09:00:00 2026  failed          smart-invest-0.1.0  Upgrade failed
4         Wed Aug 6 10:00:00 2026  deployed        smart-invest-0.1.0  Upgrade complete
```

**关键：** STATUS 列 — `deployed` 是好的，`failed` 是有问题的，回滚时要选一个 `deployed` 的 revision。

---

### 6. `helm get` — 查看 Release 的详细信息

```bash
helm get <subcommand> <release-name> [flags]
```

| 子命令 | 作用 | 示例 |
|--------|------|------|
| `values` | 查看当前合并后的所有 values | `helm get values smart-invest -n smart-invest` |
| `manifest` | 查看渲染后的完整 K8s YAML | `helm get manifest smart-invest -n smart-invest` |
| `hooks` | 查看该 release 的所有 hooks | `helm get hooks smart-invest -n smart-invest` |
| `notes` | 查看 NOTES.txt 内容 | `helm get notes smart-invest -n smart-invest` |
| `all` | 查看上面所有信息 | `helm get all smart-invest -n smart-invest` |

| 参数 | 作用 |
|------|------|
| `-n, --namespace` | 指定 namespace |
| `--revision` | 查看指定历史版本的 values/manifest | `--revision 2` |

**排查神器：** 用 `helm get values` 确认部署时实际用的 values 是什么，有时候你以为传了某个值但其实没有。
**排查神器 2：** 用 `helm get manifest --revision 3` 对比上次部署的 YAML 和这次的差异。

---

### 7. `helm show` — 查看 Chart 信息（不涉及具体 Release）

```bash
helm show <subcommand> <chart-path or repo>
```

| 子命令 | 作用 |
|--------|------|
| `values` | 查看 chart 的 values.yaml 内容 |
| `chart` | 查看 Chart.yaml 元数据 |
| `readme` | 查看 README.md |
| `all` | 查看上面所有 |

---

## 三、回滚与卸载 / Rollback & Uninstall

### 8. `helm rollback` — 回滚到指定版本

```bash
helm rollback <release-name> <revision> [flags]
```

| 参数 | 作用 |
|------|------|
| `<revision>` | 要回滚到的版本号（从 `helm history` 获取） |
| `-n, --namespace` | 指定 namespace |
| `--wait` | 等待 Pod 就绪 |
| `--timeout` | 超时时间 |
| `--dry-run` | 预览，不实际执行 |

**完整流程：**
```bash
# 1. 查看历史
helm history smart-invest -n smart-invest

# 2. 回滚到上一版本（不写版本号默认回退一个）
helm rollback smart-invest -n smart-invest

# 3. 回滚到指定版本
helm rollback smart-invest 2 -n smart-invest

# 4. 确认
helm status smart-invest -n smart-invest
kubectl get pods -n smart-invest
```

---

### 9. `helm uninstall` — 卸载 Release

```bash
helm uninstall <release-name> [flags]
```

| 参数 | 作用 |
|------|------|
| `-n, --namespace` | 指定 namespace |
| `--dry-run` | 预览，不实际删除 |
| `--keep-history` | 保留历史记录（以后可以回滚恢复） |

---

## 四、依赖管理 / Dependency Management

### 10. `helm dependency build` — 从 Chart.lock 下载依赖

```bash
helm dependency build <chart-path>
```

**作用：** 只从 `Chart.lock`（锁定文件）下载依赖。lock 文件记录了每个依赖的版本，保证可重复构建。

**我的项目：** [cd-k3s.yml](.github/workflows/cd-k3s.yml) 中 CI pipeline 用这个命令——确保 CI 环境和本地环境用同样的依赖版本。

---

### 11. `helm dependency update` — 下载依赖并更新 Chart.lock

```bash
helm dependency update <chart-path>
```

**作用：** 根据 `Chart.yaml` 中的 dependencies 下载最新匹配版本的依赖，并重新生成 `Chart.lock`。

| 场景 | 用哪个 |
|------|--------|
| 首次 clone 项目后 | `helm dependency update`（生成 lock 文件） |
| Chart.yaml 中改了依赖版本 | `helm dependency update`（更新 lock 文件） |
| CI/CD 环境中 | `helm dependency build`（只用 lock，保证可重复） |

---

### 12. `helm dependency list` — 列出依赖

```bash
helm dependency list <chart-path>
```

**作用：** 查看当前 chart 的所有依赖及其版本状态。

---

## 五、模板调试 / Template Debugging

### 13. `helm template` — 本地渲染模板（不连接 K8s 集群）

```bash
helm template <release-name> <chart-path> [flags]
```

| 参数 | 作用 |
|------|------|
| `-f, --values` | 指定 values 文件 |
| `--set` | 覆盖单个值 |
| `--debug` | 详细输出（包含模板渲染错误行号） |
| `--show-only` | 只渲染指定模板文件 | `--show-only templates/deployment.yaml` |
| `-s, --show-only` | 同上 | `-s templates/service.yaml` |
| `--validate` | 是否校验生成的 YAML（默认 true） |
| `--skip-crds` | 跳过 CRD |

**用途：**
- **不连集群也能调试**：本地检查模板渲染结果
- **CI 中的 dry-run**：在 CI 中 `helm template` + `kubectl diff` 可以预览变更
- **排模板错误**：加 `--debug` 看到底是哪一行模板语法有问题

**示例：**
```bash
# 渲染整个 chart
helm template smart-invest ./umbrella -f values-dev.yaml

# 只渲染 deployment，排查部署问题
helm template smart-invest ./umbrella --show-only charts/user-service/templates/deployment.yaml

# 输出到文件 + git diff
helm template smart-invest ./umbrella -f values-prod.yaml > /tmp/new.yaml
diff /tmp/current.yaml /tmp/new.yaml
```

---

### 14. `helm lint` — 检查 Chart 语法和规范

```bash
helm lint <chart-path> [flags]
```

| 参数 | 作用 |
|------|------|
| `--strict` | 警告也当错误处理（CI 中推荐） |
| `--with-subcharts` | 同时检查子 chart |

---

## 六、仓库管理 / Repository Management

### 15. `helm repo add` — 添加远程 Helm 仓库

```bash
helm repo add <repo-name> <url>
```

**示例：**
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
```

---

### 16. `helm repo update` — 更新本地仓库缓存

```bash
helm repo update
```

**作用：** 拉取所有已添加仓库的最新 chart 索引。类似于 `apt update`。

---

### 17. `helm search` — 搜索 Chart

```bash
helm search <subcommand> <keyword>
```

| 子命令 | 作用 | 示例 |
|--------|------|------|
| `hub` | 搜索 Artifact Hub（全球 Helm 仓库聚合站） | `helm search hub rabbitmq` |
| `repo` | 搜索本地已添加的仓库 | `helm search repo nginx` |

---

## 七、插件管理 / Plugin Management

### 18. `helm plugin` — 管理 Helm 插件

```bash
helm plugin install <url>       # 安装插件
helm plugin list                # 列出已安装的插件
helm plugin uninstall <name>    # 卸载插件
helm plugin update <name>       # 更新插件
```

**常用插件：**
| 插件 | 作用 |
|------|------|
| `helm-diff` | 显示部署前后的 YAML diff（类似 terraform plan） |
| `helm-secrets` | 支持加密的 values 文件（配合 sops 使用） |
| `helm-push` | 推送 chart 到远程仓库 |

---

## 八、完整实操流程 / Complete Operational Flow

### 部署一个新应用
```bash
# 1. 创建 chart
helm create my-app

# 2. 检查语法
helm lint ./my-app

# 3. 本地预览
helm template my-app ./my-app -f values-dev.yaml --debug

# 4. 安装
helm upgrade --install my-app ./my-app \
  -n my-ns --create-namespace \
  -f values-dev.yaml \
  --wait --timeout 300s

# 5. 确认
helm status my-app -n my-ns
kubectl get pods -n my-ns
```

### 排查部署问题
```bash
# 1. 看 Release 状态
helm status my-app -n my-ns

# 2. 看历史，确认是否是最近部署引起的
helm history my-app -n my-ns

# 3. 看实际生效的 values
helm get values my-app -n my-ns

# 4. 看生成的 K8s YAML
helm get manifest my-app -n my-ns | less

# 5. Pod 层排查
kubectl get pods -n my-ns
kubectl describe pod <bad-pod> -n my-ns
kubectl logs <bad-pod> -n my-ns --previous
```

### 紧急回滚
```bash
# 1. 确认回滚目标
helm history my-app -n my-ns

# 2. 回滚
helm rollback my-app <good-revision> -n my-ns --wait

# 3. 确认恢复
helm status my-app -n my-ns
kubectl get pods -n my-ns
```

---

> **面试重点提示：** Helm 部分面试官必问的是：
> 1. `helm upgrade --install` — 为什么加 `--install`
> 2. `helm status` → `helm history` → `helm rollback` — 回滚三步走
> 3. `helm template --debug` — 模板调试
> 4. Values 级联优先级 — 子 chart defaults < 父 values < `-f` < `--set`
