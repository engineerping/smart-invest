# 0. 前置知识：连接到哪个 AWS 账号

## 0.1. ## Terraform 与 AWS CLI 的关系

两者都用于操作 AWS 资源，但处于不同层面：

| | **Terraform** | **AWS CLI** |
|---|---|---|
| **定位** | 基础设施即代码（IaC） | 命令行管理工具 |
| **方式** | 声明式，写 `.tf` 文件描述目标状态 | 命令式，执行具体命令操作 |
| **状态** | 维护 `terraform.tfstate`，追踪资源变化 | 无状态 |
| **幂等性** | 天然幂等，自动计算增删改 | 需要自己写脚本处理 |
| **适用场景** | 批量创建/管理/销毁整套基础设施 | 查询信息、临时操作、脚本自动化 |

## 底层关系

**两者本质上是 AWS API 的不同封装层：**

```
Terraform AWS Provider → AWS SDK for Go → AWS API
AWS CLI                → botocore (Python) → AWS API
```

它们**都通过 AWS API 操作资源**，只是封装方式和调用路径不同。

## 实际使用中的关联

1. **认证方式一致**：都读取 `~/.aws/credentials`、环境变量 `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` 或 IAM 角色

2. **互补使用**：
    - Terraform：创建/管理基础设施
    - AWS CLI：临时查询状态、手动排障、操作 Terraform 不覆盖的资源

3. **Provider 配置中常引用 CLI profile**：
   ```hcl
   provider "aws" {
     profile = "prod"   # 对应 ~/.aws/credentials 中的 [prod]
     region  = "us-east-1"
   }
   ```

4. **Terraform 不管理的资源，用 CLI 弥补**：
   ```bash
   # 用 terraform 建好 EKS 后，用 aws CLI 更新 kubeconfig
   aws eks update-kubeconfig --region us-east-1 --name my-cluster
   ```

**简单说：Terraform 管"建设"，AWS CLI 管"日常操作"。两者可以独立使用，也可以协作。**


## 0.2 你的 AWS 凭证存在哪里

Terraform 和 awscli 本身不存储你的 AWS 账号信息，它们通过「凭证链」来确定连接到哪个账号。
理解这一点非常重要，否则你可能在错误的账号上操作。

AWS 凭证（Access Key + Secret Key）存储在本地文件 `~/.aws/credentials` 中：

```
[default]
aws_access_key_id     = AKIAXXXXXXXXXXXXXX
aws_secret_access_key = xxxxxxxxxxxxxxxxxxxxxxx

[my-company]
aws_access_key_id     = AKIAYYYYYYYYYYYYYY
aws_secret_access_key = yyyyyyyyyyyyyyyyyyyyyyy
```

- `[default]` 是默认凭证配置，所有不指定 profile 的命令都会用它
- `[my-company]` 是一个命名 profile，你需要显式指定 `--profile my-company` 才会使用它

## 0.3 如何查看自己当前连的是哪个 AWS 账号

```bash
# 查看默认 profile 对应的 AWS 账号
aws sts get-caller-identity

# 查看指定 profile 对应的 AWS 账号
aws sts get-caller-identity --profile my-company
```

输出示例：
```json
{
    "UserId": "AIDAXXXXXXXXXXXXX",
    "Account": "123456789012",       ← 这就是你的 AWS 账号 ID
    "Arn": "arn:aws:iam::123456789012:user/admin"
}
```

## 0.4 Terraform 怎么知道连哪个账号

看 `main.tf` 中的 provider 配置：

```hcl
provider "aws" {
  region = var.aws_region
}
```

这里只指定了 `region`，没有写 `access_key`、`secret_key` 或 `profile`。
这意味着 Terraform 会按以下优先级自动查找凭证（和 awscli 完全一致）：

```
1. 环境变量 →   export AWS_ACCESS_KEY_ID=...  AWS_SECRET_ACCESS_KEY=...
2. 凭证文件 →   ~/.aws/credentials 中的 [default] profile
3. IAM 角色 →   如果运行在 EC2 上，使用实例绑定的 IAM Role
```

> **对于本项目：** 你的 `terraform plan`、`terraform import`、`terraform apply`
> 全都会连接到 `~/.aws/credentials` 中 `[default]` profile 对应的那个 AWS 账号。
>
> 也就是说，你在终端执行 `aws sts get-caller-identity` 看到的账号，
> 就是 Terraform 将要操作的那个账号。

## 0.5 如何切换到其他 AWS 账号

```bash
# 方法1：临时切换——设置环境变量（当前终端窗口有效）
export AWS_PROFILE=my-company
terraform plan    # 本次操作使用 my-company profile

# 方法2：永久切换——修改 main.tf 中 provider
provider "aws" {
  profile = "my-company"    # 明确指定 profile
  region  = var.aws_region
}

# 方法3：直接写密钥（不推荐，容易泄露到 Git）
provider "aws" {
  access_key = "AKIA..."
  secret_key = "..."
  region     = var.aws_region
}
```

> ⚠️ 强烈推荐方法1（环境变量），不要使用方法3（会把密钥提交到 Git）。

## 0.6 确认 Terraform 操作的是正确的账号（安全检查）

在执行 `terraform apply` 或 `terraform import` 之前，养成这两个习惯：

```bash
# 习惯1：确认当前的 AWS 身份
aws sts get-caller-identity

# 习惯2：预览时也输出账号信息（plan 不会真的操作，但能让你确认连接的账号）
terraform plan
# 看 plan 输出开头有没有显示正确的 region 和资源
```

> 这就是为什么 `terraform plan` 永远是第一道安全防线——如果在错误的账号上执行，
> 你会在 plan 输出中看到意料之外的资源变化，从而及时发现问题。


# Put these files into directory smart-invest/infrastructure/aws-infra-reflect, 
# and then execute these commands:

cd smart-invest/infrastructure/aws-infra-reflect

# 1. 复制变量文件
cp terraform.tfvars.example terraform.tfvars

# 2. 初始化
terraform init

这是使用 Terraform 的第一步，任何 Terraform 项目在首次操作前都必须执行它。它做了以下事情：

2.1.下载 Provider 插件 — 你的 .tf 文件中声明了 provider "aws"，terraform init 会从 HashiCorp 
的官方仓库下载对应的 AWS Provider 二进制文件，存放到项目目录的 .terraform/ 文件夹中。Provider 是 
Terraform 和云平台之间的"翻译官"，负责将你的 HCL 配置转化为实际的 API 调用。
2.2.初始化 Backend（后端） — 如果你的配置中定义了 backend "s3" 等远程状态存储，init 会配置好它。
Backend 决定了 Terraform 的状态文件（terraform.tfstate）存放在哪里——本地磁盘还是远程的 S3 存储桶。使用远程后端可以让团队成员共享同一份状态。
2.4.安装 Module（模块） — 如果你引用了外部的 Terraform 模块（比如来自 Terraform Registry 的社区模块），init 会把它们下载下来。
2.4.创建 .terraform.lock.hcl — 锁定 Provider 的版本，确保团队所有人使用相同版本的 Provider，避免版本不一致导致的问题。


# 4. 导入 AWS 资源
Note as the infrastructure already exists, it is recommended to use `terraform import` to import existing resources into the Terraform state first,
rather than applying directly (otherwise it will attempt to recreate resources).
提示：由于您的基础设施已经存在，建议先使用 terraform import 将现有资源导入 Terraform 状态，而不是直接 apply（否则会尝试重新创建资源）。

And then execute terraform import commands for each resource to import them into the Terraform state.
or execute the script infrastructure/aws-infra-reflect/import.sh directly for all resources.
然后对每个资源执行 terraform import 命令，将它们导入 Terraform 状态。
或直接对所有资源执行脚本基础设施/aws-infra-reflect/import.sh。

# chmod +x import.sh && ./import.sh

为什么需要 import：

> Terraform 只管理它"知道"的资源——也就是记录在 terraform.tfstate 中的资源
> 如果你的 AWS 账号里已经有在运行中的资源（比如 【手动】在 AWS 控制台创建的 EC2 实例），Terraform 默认不知道它们的存在
> 如果你直接 terraform apply，Terraform 会认为"这些资源不存在，我要创建它们"，结果就是：
> 尝试创建同名资源 → 因为资源名冲突而报错
> 或者创建了重复的资源 → 浪费钱且混乱

terraform import 做了什么：

terraform import aws_instance.example i-1234567890abcdef
#                 ^^^^^^^^^^^^^^^^  ^^^^^^^^^^^^^^^^^^^^^^
#                 Terraform 配置中     AWS 中该资源的实际 ID
#                 的资源地址
> 它不会创建或修改任何 AWS 资源
> 它只是把某个已存在的 AWS 资源"登记"到 terraform.tfstate 中，让 Terraform 知道"哦，这个资源已经存在了，它对应的是配置文件中那个 aws_instance.example"
> 导入了之后，再运行 terraform plan，Terraform 就能正确对比差异，而不是想要重新创建


# 4. 预览变更
terraform plan

这是预览命令——它告诉你"如果我执行 apply，Terraform 会做什么"，但不会真的改动任何东西。

它的工作流程：
4.1.读取配置文件 — 解析你所有的 .tf 文件，理解你想要的最终状态（Desired State）
4.2.读取状态文件 — 读取 terraform.tfstate，了解当前基础设施的实际状态（Current State）
4.3.对比差异 — 将"你想要的"和"现在已有的"进行比较
4.4.生成执行计划 — 输出一份详细的变更清单，标注每个资源是：
    4.4.1. + 创建（绿色）— 需要新建的资源
    4.4.2. - 删除（红色）— 需要销毁的资源
    4.4.4. ~ 原地更新（黄色）— 需要修改现有资源
为什么重要： 这是 Terraform 的安全网。在真正部署之前先看一眼要改什么，避免不小心删掉了数据库或生产环境的关键资源。

# 5. 部署
terraform apply

这是真正执行部署的命令。它做了以下事情：

5.1.重新生成执行计划 — 和 plan 一样，先算出要改什么
5.2.要求人工确认 — 输出变更清单，然后停下来问你 Enter a value: yes，你必须手动输入 yes 才会继续。这是 Terraform 的最后一道安全防线
5.3.调用 AWS API — 确认后，Terraform 通过 AWS Provider 调用 AWS 的 API，逐一创建/修改/删除资源
5.4.更新状态文件 — 部署完成后，将最新的资源信息写入 terraform.tfstate

可选参数：
terraform apply -auto-approve — 跳过人工确认步骤，直接执行（适合 CI/CD 自动化流水线，但手动操作时不建议用）

> 整体工作流总结:
```
cp terraform.tfvars.example terraform.tfvars   ← 准备好你的配置
↓
编辑 terraform.tfvars，填入真实的 AWS 密钥         ← 配置你的密钥
↓
terraform init                                 ← 下载插件、初始化项目
↓
terraform plan                                 ← 预览：看看要改什么（此时只读，不写）
↓
terraform import <资源> <ID>                   ← 把已有资源引入 Terraform 管理
↓
terraform plan                                 ← 再次预览，确认 import 后状态正确
↓
terraform apply                                ← 正式部署！
```

# 6. 更改资源（修改已有基础设施）

导入完成后，日常工作中最常见的操作就是修改已有资源。

## 标准工作流

```
修改 .tf 或 .tfvars 文件
       ↓
terraform plan      ← 预览变更，确认要改什么
       ↓
terraform apply     ← 确认执行
       ↓
（可选）terraform show  ← 查看部署后的资源状态
```

这就是 Terraform 的核心魅力：声明式——你只需告诉它"我想要的最终状态是什么"，
它会自动算出需要调用哪些 API 来达到那个状态，不需要你手动去 AWS 控制台一步步操作。

## 示例：增加 EC2 内存到 4GB、磁盘到 10GB

EC2 的内存不是独立参数，而是由 instance_type 决定的。例如 t3.micro 只有 1GB 内存，
要获得 4GB 内存，需要换成 t3.medium（2 vCPU, 4GB 内存）。

编辑 terraform.tfvars：

```hcl
# 改前
ec2_instance_type = "t3.micro"
ebs_volume_size   = 8

# 改后
ec2_instance_type = "t3.medium"   # 2 vCPU, 4 GB 内存
ebs_volume_size   = 20            # 10 GB 磁盘
```

然后：

```bash
# 1. 预览变更
terraform plan
```

plan 输出示例：

```
  ~ aws_instance.smart_invest_server
      instance_type: "t3.micro" => "t3.medium"    # 需要重启实例

  ~ aws_instance.smart_invest_server.root_block_device
      volume_size:   8 => 10                       # 原地扩容，不中断服务
```

| 变更类型 | 影响 |
|----------|------|
| instance_type 改变 | 实例会重启（AWS 先关机再开机），有短暂服务中断，建议规划维护窗口 |
| volume_size 增大（gp3） | 磁盘原地扩容，不中断服务 |

```bash
# 2. 确认无误后，应用变更
terraform apply
# 输入 yes 确认
```

## 常用修改场景速查

| 场景 | 改什么 | 是否需要重启 |
|------|--------|-------------|
| 增加内存/CPU | 改 `ec2_instance_type` | 是，实例重启 |
| 扩大磁盘 | 改 `ebs_volume_size` | 否（gp3 支持在线扩容） |
| 改安全组规则 | 改 `security_group.tf` | 否，安全组规则即时生效 |
| 添加/修改 S3 配置 | 改 `s3.tf` | 否 |
| 修改 CloudFront 缓存 | 改 `cloudfront.tf` | 否（但部署可能有几分钟延迟） |
| 更换 AMI（系统镜像） | 改 `ec2_ami` | 是，会重建实例（数据丢失！） |

> ⚠️ 注意：更换 AMI（`ec2_ami`）会导致 Terraform 销毁旧实例并创建新实例，
> 旧的系统盘数据会丢失。请确保重要数据存储在独立的数据盘或 S3 上。


# 7. 销毁资源（删除所有基础设施）

当你不再需要这套基础设施时，可以用 `terraform destroy` 一键清理所有资源。

## 命令

```bash
# 预览将要销毁的资源（推荐先执行）
terraform plan -destroy

# 执行销毁
terraform destroy
```

## 详细说明

`terraform destroy` 做了以下事情：

7.1. **读取状态文件** — 从 `terraform.tfstate` 中获取当前所有由 Terraform 管理的资源
7.2. **生成销毁计划** — 算出需要删除哪些资源，并输出变更清单
7.3. **要求人工确认** — 输出待销毁的资源列表，然后停下来问你 `Enter a value: yes`，必须手动输入 `yes` 才会继续。这是为了防止误删
7.4. **调用 AWS API** — 确认后，Terraform 通过 AWS Provider 逐一调用 AWS API 删除资源
7.5. **清理状态文件** — 删除完成后，状态文件中的资源记录也会被清除

## 可选参数

```bash
# 跳过人工确认，直接销毁（危险！仅用于 CI/CD 或确认无误的测试环境）
terraform destroy -auto-approve
```

## 资源删除顺序

Terraform 会自动处理依赖关系，按正确的顺序删除资源。例如：
- 先删除 EC2 实例（依赖安全组）
- 再删除安全组（依赖 VPC）
- 最后删除 VPC

你也可以查看依赖图来了解删除顺序：
```bash
terraform graph | dot -Tpng > graph.png
```

## ⚠️ 重要警告

| 警告 | 说明 |
|------|------|
| **不可逆** | 一旦 `terraform destroy` 执行完毕，被删除的资源无法恢复 |
| **数据丢失** | EC2 的本地磁盘（root block device）上的所有数据将被永久删除 |
| **S3 注意** | 如果 S3 bucket 中有文件，Terraform 默认无法删除非空 bucket，会报错。需要先手动清空 bucket，或添加 `force_destroy = true` 参数 |
| **生产环境** | 生产环境执行 destroy 前，请再三确认，并确保已有备份 |
| **排除数据** | 想保留数据？在 destroy 之前，先把关键资源（如数据库、S3）配置 `prevent_destroy = true`（见 lifecycle 配置） |

## 只销毁部分资源

如果只想删除某一个资源（而不是整套基础设施），使用：

```bash
# 删除指定资源及其依赖它的资源
terraform destroy -target=aws_instance.smart_invest_server

# 预览指定资源的销毁计划
terraform plan -destroy -target=aws_instance.smart_invest_server
```

> `-target` 参数只能用于临时调试，不建议在生产环境中频繁使用。
> 最佳实践是：从 `.tf` 文件中删除资源定义，然后 `terraform apply`，
> Terraform 会自动销毁那些不再在配置中的资源。

## 防止误删：`prevent_destroy`

在关键资源（如数据库）的 `.tf` 配置中添加生命周期保护：

```hcl
resource "aws_db_instance" "production_db" {
  # ... 其他配置 ...

  lifecycle {
    prevent_destroy = true   # 禁止删除此资源
  }
}
```

这样即使执行 `terraform destroy`，该资源也会被跳过并报错，需要先手动移除此配置才能删除。

## 完整工作流回顾

```
cp terraform.tfvars.example terraform.tfvars   ← 准备好你的配置
       ↓
编辑 terraform.tfvars，填入真实的 AWS 密钥         ← 配置你的密钥
       ↓
terraform init                                 ← 下载插件、初始化项目
       ↓
terraform plan                                 ← 预览：看看要改什么
       ↓
terraform import <资源> <ID>                   ← 把已有资源引入 Terraform 管理
       ↓
terraform plan                                 ← 再次预览，确认 import 后状态正确
       ↓
terraform apply                                ← 正式部署！
       ↓
（日常）改 .tf / .tfvars → terraform plan → terraform apply   ← 修改资源
       ↓
terraform destroy                              ← 不再需要时，一键清理
