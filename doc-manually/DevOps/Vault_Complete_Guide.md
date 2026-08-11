# HashiCorp Vault 完整指南(Java 工程师视角)

> 写给资深 Java 工程师的 Vault 教学指南。
> 从「作者最初为什么开发 Vault」讲起,而不是从命令讲起。
> 理解初衷后,「Vault 是什么」「它和 Mac 钥匙串能不能等价」自然就清楚了。
> 以 smart-invest 项目(k3s 上部署微服务)为上下文。

---

## 目录

| 章节 | 内容 |
|------|------|
| 零 | 前言:先问三个问题 |
| 一 | 作者的初衷:HashiCorp 为什么开发 Vault |
| 二 | Vault 到底是什么(不是「密码本」,是「密钥管理中心」) |
| 三 | Vault 的四大核心能力 |
| 四 | Mac 钥匙串 vs Vault——能不能等价? |
| 五 | 在 smart-invest(k3s)里怎么用 Vault |
| 六 | 面试要点速查 |
| 附 | 关键术语表 |

---

## 零、前言:先问三个问题

在讲任何命令之前,先回答你问的三个问题:

1. **Vault 是什么,是用来存密码的吗?**
   —— 是,但它不只是「存」。它是**密钥全生命周期管理中心**:存、签发、轮换、吊销、审计。

2. **我可以把 Mac 自带的钥匙串(Keychain)和 Vault 等价起来吗?**
   —— **不能等价**。它们在「把敏感值存起来」这一件事上相似,但在作用范围、访问模型、生命周期、审计上完全是两个物种。详见第四章。

3. **为什么文档要从作者初衷开始讲?**
   —— 因为 Vault 的所有设计(动态密钥、租约、审计)都不是凭空拍脑袋,而是**被当年那个具体的痛点逼出来的**。理解了痛,就理解了为什么 Vault 长这样。

---

## 一、作者的初衷:HashiCorp 为什么开发 Vault

### 1.1 作者是谁

Vault 由 **HashiCorp** 公司开发,创始人是 **Mitchell Hashimoto**(也是 Vagrant 的发明者)和 **Armon Dadgar**(也是 Consul 的发明者)。

Vault 开源发布于 **2015 年 4 月 28 日**,与 Terraform、Consul 一起构成 HashiCorp 的「基础设施即代码 + 服务发现 + 密钥管理」三板斧。Vault 1.0 在 2019 年 7 月发布,标志着产品成熟。

### 1.2 开发 Vault 之前,世界是什么样子

Mitchell 在多个场合(HashiConf、Latency 2019 演讲)讲过这段历史。2014 年前后,HashiCorp 已经用 Vagrant、Packer、Terraform、Consul 构建自己的基础设施。为了跑这些工具,团队需要一堆凭证:

- 云厂商 API Key(AWS、Azure 的 access key)
- 数据库账号密码
- SSH 私钥
- CI 系统、内部工具的 Token

问题来了:**这些凭证放在哪里?** 答案是——哪儿都放:

| 存放位置 | 问题 |
|---------|------|
| 配置文件里写死 | 密码跟着代码库走,`git log` 里全是明文 |
| Shell 脚本里 `export PASSWORD=...` | 每个工程师的 `.bashrc`、剪贴板、聊天记录里到处都是 |
| 团队 Wiki / 聊天群 | 谁都能看,离职了也删不掉 |
| 每个环境各写一份 | 测试、预发、生产密码不一致,没人知道哪个是真的 |

Mitchell 讲过一个很典型的情景:他们自己就经历过「查某个环境用的密码,结果它在五个不同的文件/脚本/人脑子里」,而其中任何一个泄露,就等于把所有环境暴露了。**密钥散落 = 攻击面扩散**。

### 1.3 由此想清楚的三件「必须」的事

从「凭证散落」这个痛出发,作者们得出三个必须:

1. **必须集中**:所有密钥放一个地方,只有它能碰到底层存储。
2. **必须动态**:不要静态发一个「永远有效」的密码,而是**按需签发、到期作废**。数据库密码应该是「这个 Pod 需要时现生成,用完/过期就失效」的。
3. **必须可审计**:谁、在什么时候、读了哪个密钥,要有不可抵赖的日志。

这三点,后来变成了 Vault 的四大核心能力(见第三章)。**所以 Vault 不是「密码本的升级版」,而是针对「静态密钥是基础设施安全的最大漏洞」这一判断做的系统级回答。**

### 1.4 一句话记住初衷

> **Vault 的初衷:把散落在配置、脚本、Git、人脑里的明文凭证,收敛到一个集中、动态、可审计的密钥管理中心。**
> 类比 Java 世界:不是把 `application.yml` 里的密码加密一下,而是给整个微服务体系建一个**带权限、带审计、能签发临时凭证的中心化密钥服务**。

---

## 二、Vault 到底是什么(不是「密码本」,是「密钥管理中心」)

### 2.1 三个层次理解

**第 1 层(最浅):Vault 是一个存秘密的服务器。**
就像你在一个「加密保险库」里 `put` 一个密码,再 `get` 出来。功能上,Mac 钥匙串也做这件事。

**第 2 层:Vault 是一个「密钥服务」。**
它可以**签发**密钥,而不只是存储。比如给一个应用「现生成」一个只活 5 分钟的数据库密码;给它一个访问 AWS 的临时 IAM 凭证。这是 Mac 钥匙串根本做不到的。

**第 3 层(本质):Vault 是「动态凭证的生命周期管理器」+「静态密钥的加密保险柜」+「加密即服务」。**
它把「机密」这件事从应用的配置项,变成一个有生命周期、有权限边界、有审计痕迹的一等公民。

### 2.2 一个类比:银行金库

| Mac 钥匙串 | Vault |
|-----------|-------|
| 你家的私人保险柜 | 银行的**金库中心**(多个金库 + 服务窗口 + 摄像头) |
| 只有你能打开 | 谁可以开哪个柜子,由**授权策略(ACL)**决定 |
| 放自己的东西 | 可以**现给你铸一枚限时有效的「提款令牌」**(动态密钥) |
| 没有统一监控 | 每一次开关都有**审计录像**(audit log) |

### 2.3 Vault 的架构(先有全局观)

```
                    ┌─────────────────────────────────────────┐
                    │               Vault 服务端                │
                    │                                          │
  应用/工程师 ──────▶│   Auth Methods(认证)   ──▶  令牌/身份      │
  (Token/K8s/AppRole)│   (K8s 认证 / AppRole / Token / LDAP)    │
                    │                                          │
                    │   Policies(授权)         ──▶ 能访问哪些路径 │
                    │                                          │
                    │   Secret Engines(密钥引擎)                 │
                    │   KV / Database / AWS / Transit / ...     │
                    │                                          │
                    │   Audit Devices(审计) → 日志               │
                    └───────────────┬───────────────────────────┘
                                    │
                        ┌───────────▼───────────┐
                        │  底层存储:Consul / etcd │
                        │  / 文件(dev) / Raft     │
                        └────────────────────────┘
```

请求流程(以「数据库动态密码」为例):

1. 应用持有一个 K8s 集群签发的 ServiceAccount JWT,用 **K8s Auth Method** 登入 Vault。
2. Vault 校验后按 **Policy** 判断:它有没有权限读写 `database/creds/order-db`。
3. 应用请求 Vault **签发**一个数据库账号的临时密码。
4. Vault 在数据库里**真实创建**一个账号(TTL 比如 5 分钟),返回连接串。
5. 应用用完或 TTL 到期,Vault **吊销**该账号——密码立刻失效。
6. 整个过程写入 **Audit Device**。

---

## 三、Vault 的四大核心能力

Vault 官网一直强调四个支柱,这也是面试常考:

### 3.1 安全存储(Static Secrets + 加密存储)

- 静态秘密(数据库密码、JWT、API Key)以**加密形式**存入底层存储。
- 在 Vault 写入的数据,落盘前加密;数据在内存中也只有「已解密态」在很短时间窗口内存在。
- **关键机制:Shamir 密钥分享(解封/Unseal)**
  - Vault 启动时是「封印(sealed)」的,谁也不知道存储里是什么。
  - 需要用 n 个「解封钥匙碎片」中的 m 个(n-of-m,如 5 取 3)才能解封。
  - 好处:没有单点权限,任何一个管理员都凑不出完整密钥;服务器重启后,必须凑齐 m 个人执行 `vault operator unseal` 才能重新可用。
  - 类比:保险库的钥匙被切成了 5 段,发给 5 个不同的人,至少 3 段同时在场才能开库。

### 3.2 动态密钥(Dynamic Secrets)——Vault 最有价值的能力

静态密钥最大的问题:**永不过期、无法吊销、谁也不知道谁在用**。

动态密钥 = **按需生成、到期失效、可立即吊销**:

| 引擎 | 例子 | 返回的凭证 |
|------|------|-----------|
| `database/` | PostgreSQL / MySQL | 真实数据库账号,带随机密码,TTL 后删除 |
| `aws/` | IAM | 临时访问凭证(AccessKey+Secret+Token) |
| `azure/` | Service Principal | 临时订阅凭证 |
| `kubernetes/` | ServiceAccount | 按需创建、TTL 后删除的 SA Token |

Spring 工程师可以类比为:**不是「你把数据库密码写死在 `application.yml`」,而是「每次应用启动时,调用一个接口现领一张有效期 5 分钟的数据库密码,用完了系统自动回收」**。泄露了也不怕——几分钟后就作废了。

### 3.3 加密即服务(Transit / Encryption as a Service)

- 应用不自己管加密密钥,而是把数据发给 Vault 的 `transit` 引擎,**Vault 负责加密/解密**,应用只拿回密文/明文。
- 好处:密钥不离开 Vault,轮换密钥只动 Vault,不重发所有应用;应用代码里不需要任何加密库。
- 类比:业务系统把「需要加密的字段」交给一个中心化的加密网关,自己永远不碰密钥本身。

### 3.4 租约与续期(Lease / Renew / Revoke)

- 每一条从 Vault 出来的凭证(静态的也有 TTL 可设)都有一个**租约(Lease)**。
- 租约可以续期(Renew)、可以吊销(Revoke)、到期自动失效。
- 应用侧可以感知「凭证快过期了」,主动申请续期,实现**优雅的密钥轮换**。
- 类比:`Spring Cloud` 里的注册中心心跳——服务端知道每个实例还活着;Vault 知道每个凭证还该不该活着。

---

## 四、Mac 钥匙串 vs Vault——能不能等价?

### 4.1 先看它们相似的地方

确实有共同点,这也是你会产生「等价」疑问的原因:

| 共同点 | 说明 |
|-------|------|
| 都存敏感值 | 密码、密钥、Token,落盘都做了加密 |
| 都不让你看明文 | 都被系统保护,不直接暴露给普通用户/进程 |
| 都有解锁机制 | 钥匙串用登录密码/Touch ID;Vault 用解封碎片 |

### 4.2 再看它们本质上不同的地方

| 维度 | Mac 钥匙串(Keychain) | Vault |
|------|----------------------|-------|
| **作用范围** | 你这一台 Mac、你这一个用户 | 整个组织、成千上万个微服务、跨环境/跨机房 |
| **访问模型** | 你的登录密码解锁,本机进程可用 | 基于 Token/证书/云身份 + ACL 策略,网络访问 |
| **能否「按需签发」** | ❌ 只能存自己写进去的东西 | ✅ 动态签发 DB 密码、临时云凭证 |
| **生命周期** | 静态,放进去就是「一直有效」 | 租约制:有 TTL,可续、可吊销、到期自毁 |
| **吊销** | ❌ 改密码只能去源头改 | ✅ `vault lease revoke` 一条命令立即作废 |
| **审计** | ❌ 本机系统日志,无法集中审计 | ✅ Audit Device,谁在何时读了哪个密钥 |
| **共享** | ❌ 你的私人物品(虽有 iCloud 同步) | ✅ 多团队/多应用共享,策略隔离 |
| **多副本/高可用** | ❌ 单机 | ✅ 集群部署,底层 Consul/etcd/Raft |
| **集成生态** | ❌ 只为 macOS 服务 | ✅ K8s、CI、数据库、云厂商、Terraform 全接入 |

### 4.3 结论:为什么不能等价

**一句话:钥匙串解决「一个人的一台机器」的凭证安全,Vault 解决「一个分布式系统的凭证全生命周期」。**

用 Java 类比:

- **Mac 钥匙串 ≈** 你本机的、只有你这一个进程能读的加密 `Properties` 文件——静态、本地、无审计。
- **Vault ≈** 中心化的、带 RBAC、带审计、能签发临时凭证的「密钥 Config Server」——类比 Spring Cloud Config Server,但额外多了 **签发(issue)+ 吊销(revoke)+ 审计(audit)** 三件 Config Server 没有的事。

再回到上一份文档的 K8s Secret 话题:

```
K8s Secret(base64,非加密)  ──▶  K8s Secret + 静态加密(强一点)
                                        │
                              External Secrets Operator
                                        │
                                        ▼
                                   Vault / AWS Secrets Manager
                        (密钥真正的家,集群里只有「同步出来的影子」)
```

**Vault 可以理解为「K8s Secret 背后的密钥中心」**:K8s Secret 是给应用看的「影子副本」,Vault 是持有真身的「金库」。你的 Mac 钥匙串扮演不了这个角色——它既没有网络 API,也没有动态签发和审计。

### 4.4 钥匙串不是没价值——只是场景不同

| 场景 | 该用谁 |
|------|--------|
| 你个人开发机的 WiFi、App 登录、SSH 私钥 | **Mac 钥匙串**——够用、免运维 |
| 本机 k3s 单机 demo,密码写死也能跑 | 先用 K8s Secret,想演示生产再上 Vault |
| 多环境、多服务、要轮换、要审计 | **Vault / AWS Secrets Manager + ESO** |

---

## 五、在 smart-invest(k3s)里怎么用 Vault

结合你的工程现状([umbrella/values.yaml 里的明文 `dbPassword`](infrastructure/helm-charts/umbrella/values.yaml)):

### 5.1 当前痛点回顾

- K8s Secret 只是 base64,**不是加密**。
- `values.yaml` 里的明文密码一旦进 Git 就等于公开。
- 密码写死 → 不能按环境区分、不能轮换、泄露了无法吊销。

### 5.2 落地方案(三选一,按投入递增)

| 方案 | 做法 | 适合 |
|------|------|------|
| **A. Sealed Secrets** | 用公钥把 Secret 加密成 `SealedSecret` 进 Git,集群内 controller 解密还原成 Secret | 无外部后端、单机 k3s,想快速让明文不进 Git |
| **B. Vault + External Secrets Operator(ESO)** | Vault 存真身,ESO 把密钥同步成 K8s Secret,应用代码零改动 | 生产最佳实践,有密钥中心诉求 |
| **C. Vault Agent Injector(边车注入)** | 应用 Pod 加一个 sidecar,Vault Agent 在容器启动时注入环境变量/文件,应用无感 | 想把「动态数据库密码」也用起来 |

其中 **B 是上一份文档提到的「ESO 从 Vault 同步」的落地**,**C 能进一步发挥 Vault 的动态密钥价值**(数据库密码每次部署重新签发)。

### 5.3 最小可跑:本机 `vault dev` 起一个玩一下

```bash
# dev 模式:自动解封,直接可用(仅演示)
vault server -dev -dev-listen-address=127.0.0.1:8200

# 另开终端,登录(dev 模式会打印 root token)
export VAULT_ADDR='http://127.0.0.1:8200'
vault login <root-token>

# KV 引擎里存一条「假数据库密码」
vault kv put secret/smart-invest/db password='localdev_only'

# 读出来
vault kv get secret/smart-invest/db
```

> ⚠️ `-dev` 模式只用于学习,生产必须走 Shamir 解封 + TLS。

---

## 六、面试要点速查

| 问题 | 一句话答案 |
|------|-----------|
| Vault 是什么? | 密钥管理/机密管理服务:集中存储 + 动态签发 + 吊销 + 审计 |
| 作者为什么开发? | Mitchell Hashimoto/HashiCorp(2015):解决「明文凭证散落在配置、脚本、Git、人脑里」这个基础设施最大安全漏洞 |
| 和 K8s Secret 什么关系? | Secret 是 base64 非加密;Vault 是 Secret 背后的真身,经 ESO/Agent 同步进集群 |
| 和 Mac 钥匙串能等价吗? | 不能:钥匙串是单机、静态、无审计;Vault 是分布式、动态、可审计 |
| 动态密钥是什么? | 按需签发、到期作废、可即时吊销的临时凭证(如 5 分钟有效的 DB 密码) |
| 解封(Unseal)是什么? | Shamir 秘密分享:n 取 m 个碎片才能解开 Vault 的加密状态,防单点权限 |
| 四大支柱? | 安全存储、动态密钥、加密即服务(transit)、租约/续期/吊销 |

---

## 附、关键术语表

| 术语 | 含义 |
|------|------|
| **Secret** | Vault 里存的一条敏感值(密码、Token、证书) |
| **Secret Engine(密钥引擎)** | 一类能力:`kv`(静态存)、`database`(动态 DB 密码)、`aws`、`transit` |
| **Auth Method(认证方式)** | 你怎么证明身份:Token / AppRole / Kubernetes / LDAP |
| **Policy(策略)** | 谁能读写哪些路径的授权规则(ACL) |
| **Lease(租约)** | 每条凭证的「有效期契约」,可续期、可吊销 |
| **Dynamic Secret(动态密钥)** | 按需生成、到期失效的临时凭证 |
| **Transit(转译)** | 加密即服务:数据加解密交给 Vault,密钥不出库 |
| **Seal / Unseal(封印/解封)** | 启动时封印态;n-of-m 解封碎片解除封印 |
| **Audit Device(审计设备)** | 记录所有请求的日志后端(file / syslog / socket) |
| **ESO(External Secrets Operator)** | K8s 控制器,把外部密钥(Vault/AWS SM)同步成 K8s Secret |

---

## 参考

- HashiCorp 官方 2015-04-28 开源发布公告、Vault 1.0 发布演讲
- TechCrunch 2015-04-28: *HashiCorp Attacks Credentials Security With Open Source Secrets Manager*
- InfoWorld: *Mitchell Hashimoto follows up Vagrant with Vault key encryption*
- Mitchell Hashimoto 在 HashiConf / Latency 2019 的 Vault 起源演讲
