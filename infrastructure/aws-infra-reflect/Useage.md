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

# 6. 销毁资源
terraform destroy
