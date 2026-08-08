# Linux 系统学习指南（从 Windows 用户到熟练 DevOps 工程师）

> 面向有 Java 开发经验、但 Linux 系统知识较零散的工程师。
> 目标：从「只会敲命令」到「理解 Linux 是怎样运作的」。
> 假设你已读过 [Linux_Commands_Reference.md](Linux_Commands_Reference.md)，本指南聚焦**命令背后的原理和体系**。

---

## 目录

| 章节 | 内容 | 重要度 |
|------|------|--------|
| 零 | 思维方式转换：Windows → Linux | ★★★★★ |
| 一 | Linux 家族与发行版 | ★★★☆☆ |
| 二 | 文件系统层次结构（FHS） | ★★★★★ |
| 三 | 文件类型与 inode | ★★★★★ |
| 四 | 用户、组与权限（完整版） | ★★★★★ |
| 五 | 进程与信号 | ★★★★★ |
| 六 | Shell 与脚本基础 | ★★★★★ |
| 七 | 环境变量 | ★★★★☆ |
| 八 | systemd 与服务管理 | ★★★★★ |
| 九 | 软件包管理深度 | ★★★★☆ |
| 十 | 日志系统 | ★★★★☆ |
| 十一 | 网络配置与排查 | ★★★★☆ |
| 十二 | 磁盘与文件系统 | ★★★★☆ |
| 十三 | 定时任务（cron） | ★★★☆☆ |
| 十四 | SSH 深度配置 | ★★★★☆ |
| 十五 | 防火墙（iptables / ufw） | ★★★☆☆ |
| 十六 | DevOps 日常场景实战 | ★★★★★ |
| **十七** | **Linux 命名约定与术语词源** | ★★★★☆ |

---

## 零、思维方式转换：Windows → Linux

### 0.1 Windows 和 Linux 的根本哲学差异

| 维度 | Windows | Linux |
|------|---------|-------|
| **核心理念** | 「用户不需要知道内部怎么工作」——GUI 优先，隐藏复杂性 | 「一切皆文件、一切皆文本」——CLI 优先，透明可见 |
| **配置存储** | 注册表（二进制大仓库，`regedit` 编辑） | 文本文件（`/etc/` 目录，任何编辑器都能改） |
| **磁盘组织** | 盘符：`C:\` `D:\` `E:\` | 单一树：`/` 根目录，所有设备挂载到树中 |
| **程序安装** | `C:\Program Files\` + 注册表 | 分散到 `/usr/bin/` `/etc/` `/var/` `/lib/` 等（按功能分，不按应用分） |
| **文件扩展名** | `.exe` `.dll` `.txt`——扩展名决定文件类型 | 扩展名只是一部分——文件头 magic bytes + 权限位 `x` 决定是否可执行 |
| **大小写** | 不区分大小写（`File.txt` = `file.txt`） | 严格区分大小写（`File.txt` ≠ `file.txt`） |
| **路径分隔符** | `\`（反斜杠） | `/`（正斜杠） |

### 0.2 最重要的心态转变

**Windows 心态：** 「我点这个按钮会发生什么？」
**Linux 心态：** 「这个操作的底层做了什么？我能在哪个文本文件里看到它的配置？」

当你把「GUI 操作」替换为「读文本文件 + 执行命令」后，Linux 就变得极其透明和可预测。

### 0.3 「一切皆文件」

这是 Linux 最核心的设计哲学。在 Linux 中，这些东西**都是文件**：

| 你以为的 | Linux 中实际是 | 你可以用 `cat` / `echo` / `ls` 操作它 |
|----------|---------------|--------------------------------------|
| 硬盘分区 | `/dev/sda`（块设备文件） | `dd if=/dev/sda of=backup.img` |
| 终端窗口 | `/dev/tty`（字符设备文件） | `echo "hello" > /dev/tty1` |
| 内存 | `/dev/mem` | |
| 进程信息 | `/proc/<pid>/`（虚拟文件系统） | `cat /proc/cpuinfo` |
| 内核参数 | `/proc/sys/` | `echo 1 > /proc/sys/net/ipv4/ip_forward` |
| 网络连接 | `/proc/net/tcp` | `cat /proc/net/tcp` |
| 硬件信息 | `/sys/`（sysfs） | `cat /sys/class/net/eth0/address` |

**Java 类比：** Linux 的「一切皆文件」就像 Java 中的「一切皆对象」。`/dev/sda` 是一个文件对象，你 `open()` 它就等于打开硬盘。

---

## 一、Linux 家族与发行版

### 1.1 Linux 是什么

```
Linux = Linux Kernel（内核） + GNU 工具集（ls, cat, grep...） + 发行商打包
                                        ↑
                              「GNU/Linux」才是完整名字
                              但大家都简称 Linux
```

| 组件 | 英文 | 是谁写的 | 作用 |
|------|------|----------|------|
| **Kernel** | Linux Kernel | Linus Torvalds + 全球贡献者 | 管理硬件、进程调度、内存管理、文件系统、网络栈 |
| **Coreutils** | GNU Core Utilities | GNU 项目（Richard Stallman） | `ls` `cp` `mv` `cat` `rm` `chmod` `chown`... |
| **Shell** | Bash / Zsh | GNU 项目 | 命令行解释器 |
| **发行版** | Distribution | Canonical / Red Hat / SUSE... | 把 Kernel + GNU 工具 + 软件包管理器 + 默认配置打包 |

### 1.2 主流发行版与选用建议

```
Debian 系（用 apt）                    Red Hat 系（用 yum/dnf）
    │                                       │
    ├── Debian (稳定版首选)                  ├── RHEL (企业付费)
    ├── Ubuntu (桌面/新手首选)               ├── CentOS Stream (RHEL 上游)
    │   ├── 你的 ASUS-Ubuntu 服务器          ├── Fedora (新技术试验田)
    │   └── K3S 就跑在这上面                 └── Rocky Linux (CentOS 替代)
    └── Kali (安全渗透)
```

| 发行版 | 包管理器 | 适用场景 | 你接触过吗 |
|--------|----------|----------|-----------|
| **Ubuntu** | `apt` | 新手最佳选择，社区最大 | ✓ 你的 K3S 服务器 |
| **Debian** | `apt` | 生产服务器首选（超稳定） | |
| **Alpine** | `apk` | Docker 镜像首选（超小，~5MB） | ✓ 你的 Docker 镜像基础 |
| **RHEL/CentOS** | `yum`/`dnf` | 企业环境 | 你朋友 SAP 项目可能用 |

**面试注意：** 面试官可能问「apt 和 yum 的区别是什么？」——本质相同（都是包管理器），区别在于包格式（`.deb` vs `.rpm`）和依赖解析策略。

---

## 二、文件系统层次结构（FHS）

### 2.1 为什么 Linux 文件布局看起来「乱」

**Windows 思维：** 一个应用 = 一个文件夹（`C:\Program Files\MyApp\`），里面装着 exe + dll + 配置文件 + 数据。

**Linux 思维：** 按照**文件的用途**分类存放，而不是按应用分类。

### 2.2 FHS（Filesystem Hierarchy Standard）标准布局

这是 Linux 世界的「城市规划法」——所有发行版都遵守。

```
/                           ← 根目录：整个系统的唯一起点（没有 C: D: E:！）
│
├── /bin/                   ← bin(ary) 基础用户命令：ls, cp, cat, bash
│   (现在一般是 /usr/bin/ 的符号链接)
│
├── /sbin/                  ← s(ystem) bin 系统管理命令：fdisk, iptables, reboot
│   (需要 root 权限，/usr/sbin/ 的符号链接)
│
├── /usr/                   ← usr (Unix System Resources) 只读用户数据
│   ├── /usr/bin/            ← 绝大多数应用的可执行文件
│   │   ├── java            ← 你装的 JDK 在这
│   │   ├── mvn             ← Maven 在这
│   │   └── docker          ← Docker CLI 在这
│   ├── /usr/sbin/           ← 系统管理程序
│   ├── /usr/lib/            ← 库文件（.so = Linux 版的 .dll）
│   ├── /usr/local/          ← 手动编译安装的软件（包管理器不动它）
│   │   ├── /usr/local/bin/   ← 自己装的 k3s / helm 放这
│   │   └── /usr/local/lib/
│   └── /usr/share/          ← 架构无关的共享数据（文档、man 手册）
│
├── /etc/                   ← etc. (et cetera) 配置文件大全（这是你每天要翻的地方！）
│   ├── /etc/passwd          ← 用户账户信息
│   ├── /etc/shadow          ← 密码 hash（只有 root 能读）
│   ├── /etc/group           ← 组信息
│   ├── /etc/hostname        ← 主机名
│   ├── /etc/hosts           ← 本地 DNS（对应 Windows C:\Windows\System32\drivers\etc\hosts）
│   ├── /etc/fstab           ← f(ile) s(ystem) tab(le) 开机自动挂载的磁盘
│   ├── /etc/ssh/sshd_config ← SSH 服务端配置
│   ├── /etc/systemd/        ← systemd 服务配置文件
│   ├── /etc/apt/sources.list ← apt 软件源
│   └── /etc/rancher/k3s/    ← 你的 K3S 配置 !
│
├── /var/                   ← var(iable) 可变数据（日志、缓存、运行时数据）
│   ├── /var/log/            ← 日志文件（排查问题必看）
│   │   ├── syslog          ← 系统日志
│   │   ├── auth.log        ← 认证日志（SSH 登录记录）
│   │   └── kubelet.log     ← K3S 的 kubelet 日志
│   ├── /var/lib/            ← 应用运行时状态数据
│   │   ├── /var/lib/docker/ ← Docker 镜像 + 容器数据
│   │   └── /var/lib/kubelet/← Kubelet 数据
│   └── /var/run/            ← 运行时 PID 文件和 socket
│
├── /home/                  ← 普通用户的家目录（= Windows C:\Users\）
│   ├── /home/george/        ← 你的家目录（~）
│   └── /home/george/.ssh/   ← SSH 密钥
│
├── /root/                  ← root 用户的家目录（= Windows C:\Users\Administrator\）
│
├── /tmp/                   ← temp(orary) 临时文件（重启可能清空）
│
├── /dev/                   ← dev(ice) 设备文件
│   ├── /dev/sda             ← 第一块 SCSI/SATA 硬盘
│   ├── /dev/sda1            ← 第一个分区
│   ├── /dev/null            ← 黑洞设备（写什么都消失）
│   └── /dev/zero            ← 无限输出零
│
├── /proc/                  ← proc(ess) 虚拟文件系统：内核和进程信息（只存在内存中）
│   ├── /proc/cpuinfo        ← CPU 信息
│   ├── /proc/meminfo        ← 内存信息
│   ├── /proc/<pid>/         ← 每个进程一个目录
│   │   └── /proc/<pid>/environ ← 进程启动时的环境变量
│   └── /proc/sys/net/       ← 内核网络参数（可修改！）
│
├── /sys/                   ← sys(fs) 内核与硬件信息（比 /proc 更结构化）
│
├── /boot/                  ← 启动文件：内核镜像（vmlinuz）+ initrd + GRUB 配置
│
├── /opt/                   ← opt(ional) 自己装的「大型第三方软件」
│   └── /opt/smart-invest/   ← 你的项目放这！（部署脚本创建的）
│
└── /mnt/  /media/          ← 临时挂载点（插 U 盘、挂载网络存储）
```

### 2.3 一个命令验证你的 FHS 理解

```bash
# 看看你的系统里都有什么
ls /
ls /etc | head -20
ls /var/log

# 在 K3S 上跑
ssh george@192.168.31.192 'ls /'             # 看看和 Mac 有什么不同
ssh george@192.168.31.192 'ls /var/lib'      # 找找 kubelet 和 docker 的数据
ssh george@192.168.31.192 'ls /etc/rancher'  # K3S 配置
```

---

## 三、文件类型与 inode

### 3.1 Linux 的 7 种文件类型

```bash
ls -l
# -rwxr-xr-x  1 george george  12345 Aug  5 10:00 app.jar
# ↑
# 第一个字符就是文件类型
```

| 第一个字符 | 类型 | 英文 | 说明 |
|-----------|------|------|------|
| `-` | 普通文件 | Regular File | Java 源文件、jar 包、文本、图片 |
| `d` | 目录 | Directory | 就是文件夹 |
| `l` | 符号链接 | symbolic Link | 快捷方式（`ln -s` 创建） |
| `b` | 块设备 | Block Device | 硬盘 `/dev/sda` |
| `c` | 字符设备 | Character Device | 键盘、鼠标、终端 `/dev/tty` |
| `s` | Socket | Socket | 进程间通信（如 `docker.sock`） |
| `p` | 管道 | named Pipe (FIFO) | 进程间通信 |

```bash
ls -l /var/run/docker.sock
# srw-rw---- 1 root docker 0 Aug  5 10:00 /var/run/docker.sock
# ↑ s = socket 文件
```

### 3.2 inode（索引节点）——文件在磁盘上的「身份证」

这是 Windows 用户最容易忽略的概念。

**每个文件和目录在磁盘上都有一个唯一的 inode 号。** 文件名只是 inode 的标签，真正的元数据（权限、大小、时间戳、数据块位置）存在 inode 里。

```
一个文件的构成：
  ┌──────────────────────┐
  │   目录项 (Directory Entry)  │
  │  文件名 = "app.jar"        │  ← 你看到的
  │  inode = 123456            │  ← 指向 inode 的指针
  └──────────┬───────────┘
             │
  ┌──────────▼───────────┐
  │      inode #123456    │
  │  - 权限：rwxr-xr-x    │
  │  - 所有者：1001       │
  │  - 大小：50MB         │
  │  - 时间戳（mtime/atime/ctime）│
  │  - 数据块指针 → 磁盘上真正存数据的位置 │
  └──────────────────────┘
```

**验证：**

```bash
ls -i                       # -i = inode，显示每个文件的 inode 号
stat app.jar                # 查看文件的所有元数据
df -i                       # 看 inode 使用情况（小文件太多会导致 inode 耗尽！）
```

**面试考点：** `df -h` 显示磁盘还有空间，但 `touch` 说 "No space left on device" → 很可能是 inode 用完了而不是空间用完。用 `df -i` 确认。

**关键理解——硬链接和软链接的 inode 原理：**

```bash
# 软链接（符号链接）：有自己的 inode，内容是目标路径
ln -s /usr/bin/java /usr/local/bin/java
ls -li /usr/local/bin/java
# lrwxr-xr-x  ...  /usr/local/bin/java -> /usr/bin/java
# inode 不同！软链接是独立的文件

# 硬链接：多个文件名指向同一个 inode
ln /usr/bin/java /usr/local/bin/java2
ls -li /usr/bin/java /usr/local/bin/java2
# 两个文件的 inode 号相同！它们是同一个文件的别名
# 删除其中一个不影响另一个；只有当 inode 的引用计数归零才真正删除
```

---

## 四、用户、组与权限（完整版）

### 4.1 用户和组在哪个文件里

```bash
# 用户信息：每行是一个用户
cat /etc/passwd
# george:x:1000:1000:George Cui:/home/george:/bin/bash
#  ↑       ↑  ↑    ↑    ↑           ↑            ↑
#  用户名   pw  UID  GID  全名       家目录        默认shell

# 密码 hash：只有 root 能读
sudo cat /etc/shadow
# george:$6$rounds=...:19650:0:99999:7:::
#       ↑ 加密后的密码

# 组信息
cat /etc/group
# docker:x:998:george     ← george 在 docker 组里
```

### 4.2 权限位的完整解读

```bash
ls -l app.jar
# -rwxr-xr--  1 george  developers  52428800 Aug  5 10:00 app.jar
#  ↑  ↑  ↑     ↑       ↑
#  │  │  │     │       └── 所属组 (group)
#  │  │  │     └── 所有者 (owner)
#  │  │  └── other（其他人） r-- = 只读
#  │  └── group（组）       r-x = 读+执行
#  └── owner（所有者）      rwx = 读+写+执行
```

**八进制权限速算：**

| 八进制 | 权限 | 记忆 |
|--------|------|------|
| 4 | `r--` | **R**ead = 4 |
| 2 | `-w-` | **W**rite = 2 |
| 1 | `--x` | E**x**ecute = 1 |

| 常用组合 | 八进制 | 含义 |
|----------|--------|------|
| `rwxr-xr-x` | 755 | 常见可执行文件/目录：owner 全权限，其他读+执行 |
| `rw-r--r--` | 644 | 常见普通文件：owner 读写，其他只读 |
| `rw-------` | 600 | 私钥文件：只有 owner 能读写 |
| `rwx------` | 700 | 私有目录 |

### 4.3 目录权限的特殊含义

**目录权限和文件权限含义完全不同！**

| 权限 | 对文件的含义 | 对目录的含义 |
|------|-------------|-------------|
| `r` | 能读文件内容 | 能 `ls` 列出目录中的文件名 |
| `w` | 能修改文件内容 | 能在目录中创建/删除/重命名文件 |
| `x` | 能执行文件 | 能 `cd` 进入目录（也叫 search 权限） |

**常见陷阱：**
```bash
# 目录有 r 和 r-x 的区别
dr--r--r--  目录    → 能 ls 看到文件名，但不能 cd 进去！x 权限缺失
drwxr-xr-x  目录    → 正常：能进、能看

# 文件删除的权限取决于目录的 w！不是你自己的文件就不能删！
# 你在 /tmp 下放了一个 700 的文件（只有你能读）
# 但 /tmp 目录是 777 的 → 其他人虽然读不了你的文件，但可以删除它
```

### 4.4 umask——新文件的默认权限

每次你创建文件时，Linux 会根据 umask 来屏蔽某些权限位。

```bash
umask           # 查看当前 umask。通常是 0022 或 0002

# 新建文件的最大权限是 666（rw-rw-rw-），减去 umask
# umask=022 → 666-022=644（rw-r--r--）
# umask=002 → 666-002=664（rw-rw-r--）
```

### 4.5 sudo 的原理

`sudo` = **s**uper**u**ser **do**。它不要求你知道 root 密码，而是检查 `/etc/sudoers` 中的规则。

```bash
sudo cat /etc/sudoers
# george  ALL=(ALL:ALL) ALL
# ↑        ↑            ↑
# 用户     在哪台机器    可以以谁的身份执行什么命令
```

---

## 五、进程与信号

### 5.1 进程的「家谱」——父子关系

Linux 中所有进程形成一个树——init（PID 1）是所有进程的祖先。

```bash
ps auxf                     # f = forest（树状显示父子关系）
pstree -p                   # 另一种树状显示
```

**关键理解：**
- 每个进程（除了 init）都有一个父进程（PPID）
- 父进程「fork」自己创建一个子进程，然后子进程「exec」替换成新程序
- 子进程死了 → 变成 Zombie（僵尸），需要父进程 `wait()` 回收
- 父进程先死了 → 子进程变成 Orphan（孤儿），被 PID 1 收养

**这和 Docker 的关系：**
```bash
# 容器内 PID 1 就是你的 ENTRYPOINT/CMD
docker top user-service
# 看到 java 进程是 PID 1

# 这个 PID 1 必须正确处理 SIGTERM 信号
# 如果你的 CMD 是 shell 形式（CMD java -jar app.jar），
# PID 1 是 /bin/sh，它不转发信号给 java！
# 这就是 Dockerfile 中要用 exec 形式（CMD ["java","-jar","app.jar"]）的原因
```

### 5.2 信号的完整介绍

| 信号 | 编号 | 全称 | 含义 | 默认行为 |
|------|------|------|------|----------|
| SIGTERM | 15 | **Term**ination | 「请你优雅退出」 | 进程可以捕获并处理 |
| SIGKILL | 9 | **Kill** | 「立即死」 | 不能被捕获或忽略 |
| SIGINT | 2 | **Int**errupt | Ctrl+C | 同 Ctrl+C |
| SIGHUP | 1 | **H**ang**U**p | 终端断开时发出 | 重新加载配置 |
| SIGQUIT | 3 | **Quit** | Ctrl+\ | 退出 + core dump |
| SIGSTOP | 19 | **Stop** | 暂停进程 | 不能被捕获 |
| SIGCONT | 18 | **Cont**inue | 恢复暂停的进程 | — |
| SIGUSR1/2 | 10/12 | **Us**e**r** Signal | 用户自定义 | — |

**面试高频场景——K8s 优雅停机的信号序列：**
```
1. kubectl delete pod
2. K8s 给 Pod 中的 PID 1 发 SIGTERM（15）
3. preStop hook 执行（如 curl /actuator/shutdown）
4. 应用开始优雅关闭：拒绝新请求，处理完在途请求
5. terminationGracePeriodSeconds 超时
6. K8s 发 SIGKILL（9）强制杀死
```

### 5.3 后台进程与会话

```bash
# 几种后台运行方式
command &                           # 后台运行，但终端关了进程也关
nohup command &                     # 忽略 SIGHUP，关终端也不死
nohup command > /dev/null 2>&1 &   # 后台 + 丢弃输出
disown                              # 把后台作业从 shell 的作业表中移除

# 用 screen/tmux 保持会话
# DevOps 推荐 tmux
tmux new -s deploy                  # 创建名为 deploy 的会话
# 在里面跑长时间任务，Ctrl+B D 脱离
tmux attach -t deploy               # 重新连接
```

---

## 六、Shell 与脚本基础

### 6.1 Shell 是什么

```
你敲命令 → Shell (bash/zsh) 解释并执行 → Linux Kernel
```

Shell 是一个**命令解释器**，同时也是一门编程语言。你每天敲的 `ls -la` 就是 shell 命令。

```bash
echo $SHELL                         # 查看当前用的 shell
cat /etc/shells                     # 系统装了哪些 shell
```

### 6.2 Shell 脚本基础——为 DevOps 工作流定制

**基础结构：**
```bash
#!/bin/bash                         # shebang：指定解释器（必须是第一行）
set -euo pipefail                   # 严格模式（DevOps 脚本必备！）

# set -e  : 任何命令失败立即退出（不继续执行）
# set -u  : 使用未定义变量时报错
# set -o pipefail : 管道中任何一个命令失败都算失败
```

**变量：**
```bash
NAME="george"                        # 注意：等号两边不能有空格！
echo "Hello, ${NAME}"               # ${} 是安全写法
echo "Hello, $NAME"                 # 也可以不加花括号

# 特殊变量
echo $0                             # 脚本名
echo $1 $2 $3                       # 第 1/2/3 个参数
echo $#                             # 参数个数
echo $@                             # 所有参数（每个作为独立字符串）
echo $?                             # 上一个命令的退出码（0=成功）
```

**条件判断：**
```bash
# [ ] vs [[ ]]
# [ ] 是传统写法（POSIX），[[ ]] 是 bash 增强版

if [[ -f "/etc/hosts" ]]; then      # -f = 文件存在
    echo "hosts file exists"
fi

# 常用条件表达式
[[ -f file ]]    # 是不是普通文件？
[[ -d dir ]]     # 是不是目录？
[[ -x file ]]    # 是不是可执行？
[[ -z "$var" ]]  # 变量是否为空？
[[ -n "$var" ]]  # 变量是否非空？
[[ "$a" == "$b" ]]  # 字符串相等
```

**循环：**
```bash
# DevOps 最常用的循环：批量操作
for svc in user-service fund-service order-service; do
    echo "Building ${svc}..."
    docker build -t gongchengship/smart-invest-${svc}:latest \
      -f backend/${svc}/Dockerfile backend/
done
```

### 6.3 实战——把一个 Jenkins/GitHub Actions 的 step 翻译成 shell

```bash
#!/bin/bash
# 这是你的 cd-k3s.yml 中 "Build & push backend images" 步骤的 shell 版本
set -euo pipefail

REGISTRY="gongchengship"
IMAGE_TAG="${1:-latest}"
SERVICES="user-service fund-service order-service notification-worker api-gateway"

for svc in ${SERVICES}; do
    echo ">>> Building ${svc}..."
    docker build \
        -t ${REGISTRY}/smart-invest-${svc}:${IMAGE_TAG} \
        -t ${REGISTRY}/smart-invest-${svc}:latest \
        -f backend/${svc}/Dockerfile backend/

    echo ">>> Pushing ${svc}..."
    docker push ${REGISTRY}/smart-invest-${svc}:${IMAGE_TAG}
    docker push ${REGISTRY}/smart-invest-${svc}:latest
done

echo ">>> All done!"
```

---

## 七、环境变量

### 7.1 环境变量存在哪

环境变量是**每个进程都有一份**的内存空间，Linux 不把它存在磁盘文件中。

```bash
env                          # 列出当前 shell 的所有环境变量
printenv PATH                # 看单个变量
echo $PATH                   # 同上
```

### 7.2 PATH——你每敲一条命令都在用它

```bash
echo $PATH
# /usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

# 当你敲 kubectl 时：
# 1. Shell 在 PATH 中从左到右找可执行文件
# 2. 第一个目录找不到 → 找第二个
# 3. 在 /usr/local/bin/kubectl 找到了 → 执行
# 4. 所有目录都找不到 → command not found
```

### 7.3 环境变量怎么持久化

**环境变量的生命周期 = 进程的生命周期。** 要让变量永久有效，必须写进配置文件。

```bash
# 按照加载顺序：

# 1. 系统级（所有用户生效）
/etc/environment                        # 这个最早加载（PAM）
/etc/profile                            # 登录 shell 时加载
/etc/bash.bashrc                        # 每个新 bash 窗口都加载

# 2. 用户级（只对你生效）
~/.profile                              # 登录 shell
~/.bashrc                               # 每个新 bash 窗口
~/.bash_profile                         # macOS 常用

# 3. DevOps 最常用的做法：在 ~/.bashrc 末尾加
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64
export PATH=$PATH:/usr/local/bin/helm

# 4. 立即生效
source ~/.bashrc                        # 重新加载配置
```

**`export` 是什么意思？**
```bash
FOO=bar              # 只在当前 shell 有效。子进程看不到
export FOO=bar       # 当前 shell + 所有子进程都看得到
# 这就是为什么需要 export：让变量传递给子进程
```

---

## 八、systemd 与服务管理

### 8.1 什么是 systemd

**systemd** = **System** **D**aemon。它是现代 Linux 的 init 系统（PID 1），负责**启动和管理所有系统服务**。

```
内核启动
  ↓
systemd (PID 1)
  ├── 挂载文件系统
  ├── 启动网络
  ├── 启动 SSH (sshd)
  ├── 启动 Docker (dockerd)
  ├── 启动 cron
  └── 启动 K3S (k3s.service)
```

### 8.2 systemctl——DevOps 每天必用的命令

```bash
systemctl status k3s                    # 看 K3S 运行状态
systemctl start k3s                     # 启动
systemctl stop k3s                      # 停止
systemctl restart k3s                   # 重启
systemctl reload nginx                  # 重载配置（不中断服务）
systemctl enable k3s                    # 开机自启
systemctl disable k3s                   # 取消开机自启
systemctl is-enabled k3s                # 看是否开机自启
systemctl list-units --state=failed     # 看哪些服务挂了
journalctl -u k3s -f                    # 看 K3S 日志（实时）
journalctl -u k3s --since "10 min ago"  # 最近 10 分钟日志
```

### 8.3 看懂一个 systemd service 文件

```bash
cat /etc/systemd/system/k3s.service
```

```ini
[Unit]
Description=Lightweight Kubernetes       # 服务描述
Documentation=https://k3s.io
After=network-online.target              # 在网络就绪后启动

[Service]
Type=notify                              # 服务启动后主动通知 systemd
ExecStart=/usr/local/bin/k3s server      # 启动命令
Restart=always                           # 挂了总是重启
RestartSec=5s                            # 等 5 秒再重启
LimitNOFILE=65536                        # 最大文件描述符数

[Install]
WantedBy=multi-user.target               # 在多用户模式下启动
```

**面试：** 如果面试官问「怎么让 K3S 开机自启」，就是 `systemctl enable k3s`。

---

## 九、软件包管理深度

### 9.1 apt 的工作原理

```bash
# /etc/apt/sources.list 定义了从哪些 URL 下载软件
cat /etc/apt/sources.list

# apt 命令家族
apt update                  # 更新软件包索引（不安装任何东西）
apt upgrade                 # 升级所有可升级的包
apt full-upgrade            # 升级（允许删除冲突的包）
apt install <package>       # 安装
apt remove <package>        # 卸载但保留配置
apt purge <package>         # 彻底删除（含配置）
apt search <keyword>        # 搜索
apt show <package>          # 查看包详情
apt list --installed        # 已安装的包
apt autoremove              # 删孤儿依赖
```

### 9.2 包管理的实际场景

```bash
# 装 Docker
sudo apt update
sudo apt install docker.io

# 装特定版本的软件
apt list -a containerd      # 看有哪些版本
sudo apt install containerd=1.7.2-0ubuntu1

# 查看某个文件属于哪个包
dpkg -S /usr/bin/docker     # 看 /usr/bin/docker 是谁装的
```

---

## 十、日志系统

### 10.1 Linux 日志在哪

```bash
# 传统方式（rsyslog/syslog-ng）
ls /var/log/
# syslog     = 系统日志
# auth.log   = SSH 登录记录
# kern.log   = 内核日志
# dpkg.log   = 软件包安装历史

# 现代方式（journald = systemd 的日志组件）
journalctl                     # 所有日志
journalctl -f                  # 实时（类似 tail -f）
journalctl -u k3s              # 只看 K3S 日志
journalctl -u k3s --since today
journalctl -u k3s -p err       # 只看 Error 及以上级别
```

### 10.2 DevOps 日志排查实战

```bash
# 看谁 SSH 登录了
sudo cat /var/log/auth.log | grep Accepted

# 看最近的 sudo 操作
sudo journalctl | grep sudo

# 看上一次重启时间
last reboot

# 看上一次登录的用户
last | head -10
```

---

## 十一、网络配置与排查

### 11.1 网络配置在哪

```bash
# 看 IP 地址
ip addr show                    # 替代旧命令 ifconfig
hostname -I                     # 只看 IP

# 看路由表
ip route show                   # 替代旧命令 route -n
# 关注 default via x.x.x.x 那行，那是你的网关

# 看 DNS 配置
cat /etc/resolv.conf
# nameserver 192.168.31.1   ← 你的 DNS 服务器

# 看 hosts
cat /etc/hosts
# 192.168.31.192  postgres-host  ← 你项目中的 --add-host
```

### 11.2 网络排查三步走

```bash
# Step 1: 自己有没有网
ip addr show | grep inet
ping -c 3 8.8.8.8                          # 公网通不通

# Step 2: DNS 能不能解析
nslookup google.com                         # 解析不了→检查 /etc/resolv.conf

# Step 3: 目标服务通不通
nc -zv 192.168.31.192 6443                  # K3S API Server 端口
curl -v http://localhost:8081/health        # 本地应用
```

---

## 十二、磁盘与文件系统

### 12.1 文件系统类型

| 类型 | 全称/说明 | 适用场景 |
|------|-----------|----------|
| **ext4** | Fourth Extended Filesystem | Linux 默认文件系统（你的 K3S 服务器用的就是这个） |
| **XFS** | — | 大文件场景（Red Hat 默认） |
| **Btrfs** | B-Tree File System | 高级功能（快照、压缩） |
| **ZFS** | Zettabyte File System | 企业级（Sun 发明的），校验和 + 快照 + 压缩 |
| **tmpfs** | Temporary File System | 存内存里（`/tmp`、`/dev/shm`），重启就没了 |
| **NFS** | Network File System | 网络共享存储 |
| **overlay** | OverlayFS | Docker 镜像的分层文件系统 |

### 12.2 挂载（mount）——Windows 没有的概念

**Windows：** 插 U 盘 → 自动分配 `E:\`。不同磁盘不同盘符。
**Linux：** 所有存储设备（硬盘、U 盘、网络盘）都挂载到 `/` 树的某个目录下。

```bash
mount                        # 看所有挂载
df -h                        # 快速看磁盘
lsblk                        # 看所有块设备
sudo fdisk -l                # 看磁盘分区表

# 手动挂载 U 盘
sudo mount /dev/sdb1 /mnt/usb
sudo umount /mnt/usb
```

### 12.3 /etc/fstab——开机自动挂载

```bash
cat /etc/fstab
# UUID=a1b2c3...  /               ext4  defaults  0  1
# UUID=d4e5f6...  /mnt/data       ext4  defaults  0  2
#  ↑              ↑               ↑     ↑         ↑  ↑
#  设备(UUID)     挂载点          文件系统 选项     dump  fsck顺序
```

---

## 十三、定时任务（cron）

### 13.1 cron 的层级

```
系统级 /etc/crontab             ← 不推荐直接改
系统级 /etc/cron.d/             ← 系统定时任务目录
系统级 /etc/cron.daily/         ← 每天自动执行
系统级 /etc/cron.hourly/        ← 每小时自动执行
用户级 crontab -e               ← DevOps 最常用
```

### 13.2 crontab 实操

```bash
crontab -e
# 格式：分 时 日 月 星期 命令

# 每天凌晨 2 点备份数据库
0 2 * * * pg_dump smartinvest > /backup/db_$(date +\%Y\%m\%d).sql

# 每 5 分钟检查 K3S Pod 状态并写日志
*/5 * * * * kubectl get pods -n smart-invest >> /var/log/pod-check.log

# 每天 3 点清理 7 天前的日志
0 3 * * * find /var/log -name "*.log" -mtime +7 -delete

# 查看任务列表
crontab -l
```

---

## 十四、SSH 深度配置

### 14.1 SSH 密钥——身份认证

```bash
# 生成密钥对
ssh-keygen -t ed25519 -C "georgecuiwill@gmail.com"
# 产生两个文件：
#   ~/.ssh/id_ed25519      ← 私钥（绝对不能泄露！）
#   ~/.ssh/id_ed25519.pub  ← 公钥（放到服务器上）

# 把公钥放到服务器
ssh-copy-id george@192.168.31.192
# 之后就可以免密码登录了

# 配置 SSH 简化登录
cat ~/.ssh/config
# Host asus
#     HostName 192.168.31.192
#     User george
#     IdentityFile ~/.ssh/id_ed25519

# 然后一行搞定！
ssh asus "kubectl get pods -n smart-invest"
```

### 14.2 服务端安全配置

```bash
sudo vim /etc/ssh/sshd_config
```

```ini
# 安全最佳实践
Port 22                              # 改成非标准端口（如 2222）减少扫描
PermitRootLogin no                   # 禁止 root 直接 SSH
PasswordAuthentication no            # 禁用密码登录→只用密钥
PubkeyAuthentication yes             # 开启公钥认证
MaxAuthTries 3                       # 最多试 3 次
ClientAliveInterval 300              # 每 5 分钟发心跳保活
```

---

## 十五、防火墙（iptables / ufw）

### 15.1 iptables——底层

```bash
# iptables 按表→链→规则三层组织
sudo iptables -L -n -v               # 看所有规则
sudo iptables -t nat -L -n -v        # 看 NAT 规则（Istio 和 Docker 都在这加规则）
sudo iptables-save                   # 备份当前规则
```

### 15.2 ufw——人类可用的防火墙

```bash
# ufw = Uncomplicated FireWall
# 在 Ubuntu 上，ufw 是 iptables 的友好前端

sudo ufw status
sudo ufw enable                       # 开启
sudo ufw allow 22                     # 允许 SSH
sudo ufw allow 6443/tcp               # 允许 K3S API Server
sudo ufw allow from 192.168.31.0/24   # 允许内网
sudo ufw default deny incoming        # 默认拒绝所有入站
```

---

## 十六、DevOps 日常场景实战

### 场景 1：新服务器到手，做初始化

```bash
# 1. 更新系统
sudo apt update && sudo apt upgrade -y

# 2. 设置时区
sudo timedatectl set-timezone Asia/Shanghai

# 3. 创建用户
sudo useradd -m -s /bin/bash deploy
sudo usermod -aG docker deploy        # 加入 docker 组

# 4. 配置密钥
ssh-copy-id deploy@server

# 5. 加固 SSH（禁用密码 + 禁用 root）
sudo vim /etc/ssh/sshd_config
sudo systemctl restart sshd

# 6. 开防火墙
sudo ufw allow 22
sudo ufw enable

# 7. 装常用工具
sudo apt install -y htop net-tools curl wget vim git jq
```

### 场景 2：排查磁盘满了

```bash
df -h                                  # 确认哪个分区满了
du -h --max-depth=1 / | sort -hr | head -10  # 从根目录一层层找大目录
du -sh /var/lib/docker/*               # Docker 镜像太大？
docker system prune -a -f              # 清理
journalctl --disk-usage                # journald 日志太大？
sudo journalctl --vacuum-size=500M     # 限制 500MB
```

### 场景 3：排查 CPU/内存高

```bash
top                                    # 看谁在吃 CPU
# 按 P = 按 CPU 排序，按 M = 按内存排序

free -h                                # 内存总览

# 看具体进程的线程
top -H -p <pid>                        # 看某个 Java 进程的所有线程

# 看 OOM 历史
dmesg | grep -i "out of memory"
dmesg | grep -i "killed process"
```

### 场景 4：定时巡检脚本

```bash
#!/bin/bash
# health-check.sh —— 放 crontab 每小时跑一次

echo "=== Health Check $(date) ==="

# K3S Pod 状态
kubectl get pods -n smart-invest | grep -v Running | grep -v NAME

# 磁盘
df -h / | awk 'NR==2 {print "Disk: "$5" used"}'

# 内存
free -h | awk 'NR==2 {print "Memory: "$3" used out of "$2}'

# 最近 5 分钟的异常日志
journalctl --since "5 min ago" -p err --no-pager
```

### 场景 5：在服务器和本地之间高效传文件

```bash
# 传目录（rsync 比 scp 聪明——只传差异）
rsync -avzP ./helm-charts/ george@192.168.31.192:/opt/smart-invest/helm-charts/

# 把服务器的日志拉回来看
rsync -avz george@192.168.31.192:/var/log/k3s*.log ./logs/

# 用 SSH 隧道转发端口（本地调试服务器上的服务）
ssh -L 8081:localhost:8081 george@192.168.31.192
# 然后访问 http://localhost:8081 就等于访问服务器的 localhost:8081
```

---

## 十七、Linux 命名约定与术语词源 / Naming Conventions & Etymology

### 17.1 进程/服务名中的 `d` 后缀——Daemon（守护进程）

**你问的 `systemd`、`containerd`、`dockerd` 中的 `d` 是什么？**

> **答案：`d` = `daemon`（守护进程，发音 `/ˈdiːmən/` = 「迪蒙」）**

**什么是 Daemon（守护进程）？**

Daemon 是一种在**后台持续运行**的进程，不和终端交互，默默做它被安排的工作。类比 Java 中的 Daemon Thread（守护线程）——JVM 退了它就退，平时不被感知。

```
普通进程（Foreground Process）：
  $ ./deploy.sh
  Running...     ← 你盯着它，它跑完你就知道
  Done.          ← 跑完了就消失

守护进程（Daemon）：
  $ systemctl start k3s
  $               ← 命令立即返回，shell 还给你
                  ← k3s 在后台默默运行，你完全感觉不到它的存在
                  ← 但它确实在监听 6443 端口、调度 Pod、处理流量
```

**Daemon 的特征：**
- 后台运行，不占用终端
- 通常开机自启（`systemctl enable xxx`）
- 名字通常以 `d` 结尾
- PID 通常很小（启动早）

**DevOps 工作中每天打交道的 Daemon：**

| 进程名 | 全称 | 它是干什么的 |
|--------|------|-------------|
| **systemd** | **System** **D**aemon | Linux 的 PID 1——所有进程的祖先。负责启动和管理所有系统服务 |
| **dockerd** | **Docker** **D**aemon | Docker 的后台服务。接收 docker CLI 的请求，管理镜像、容器、网络 |
| **containerd** | **Container** **D**aemon | 容器运行时守护进程。dockerd 把「创建容器」的任务交给 containerd 执行 |
| **kubelet** | **Kube** + **let**（小后缀，见 17.3） | 每个 K8s 节点上的代理——不是 Controller，而是执行者 |
| **sshd** | **S**ecure **Sh**ell **D**aemon | SSH 服务端。监听 22 端口，接受你的 `ssh` 连接 |
| **crond** | **Cron** **D**aemon | 定时任务服务。到了你设的时间就执行你指定的命令 |
| **journald** | **Journal** **D**aemon | systemd 的日志组件。收集所有服务的 stdout/stderr |
| **rsyslogd** | **R**eliable **Syslog** **D**aemon | 传统系统日志守护进程。把日志写到 `/var/log/` |
| **ntpd** | **N**etwork **T**ime **P**rotocol **D**aemon | 时间同步守护进程。保证服务器时间是准的 |
| **httpd** | **H**yper**t**ext **T**ransfer **P**rotocol **D**aemon | Apache HTTP Server 的守护进程名 |
| **mysqld** | **MySQL** **D**aemon | MySQL 数据库的守护进程 |

**查看你服务器上的所有 daemon：**

```bash
# 看所有带 d 后缀的服务进程
ps aux | grep 'd$' | head -20
# 或者
ps -eo pid,cmd | grep -E '(d$|d )' | head -20

# 看 systemd 管理的所有 daemon 服务
systemctl list-units --type=service | grep 'd\.service'

# 在你的 K3S 服务器上跑：
ssh george@192.168.31.192 'ps aux | grep -E "(dockerd|containerd|k3s|systemd|sshd)" | grep -v grep'
```

---

### 17.2 `systemd` 这个名字的含义

```
systemd 的名字很简单：

  system  +  d
    ↑         ↑
  系统       daemon = 守护进程（Unix 命名惯例，见 17.1）

  → "系统守护进程"
```

**没有彩蛋，没有双关。** Wikipedia 对 systemd 名字的记载是：

> *"The name systemd adheres to the Unix convention of making daemons easier to distinguish by having the letter 'd' as the last one in their actual filenames."*
>
> —— "systemd 这个名字遵循 Unix 惯例：守护进程的文件名以 `d` 结尾，以便于区分。"

**但是 systemd 确实替代了 System V init：**

这不是名字里的彩蛋，而是历史事实——systemd 是 System V init 的继任者。System V init（发音 "system five"）是 AT&T Unix System V 时代定义的传统 init 系统，用 `/etc/init.d/` 下的 shell 脚本管理服务启动。systemd 取代了它，但**名字本身并无关联。**

```
System V init（旧）           →    systemd（新）
├── /etc/init.d/ shell 脚本    →    ├── systemd unit 文件（声明式）
├── runlevel 0-6              →    ├── target（graphical.target 等）
├── 串行启动                   →    ├── 并行启动（快得多）
└── 只管启动，不管运行          →    └── 管启动 + 运行 + 日志 + 资源限制
```

**在 Linux 上亲手验证：**

```bash
# 老一代 init（System V）——大多数发行版已改为兼容 systemd 的 symlink
ls -l /sbin/init
# → /sbin/init -> /lib/systemd/systemd    ← 看！init 现在指向 systemd

# systemd 确实接管了 PID 1
ps -p 1 -o comm=                          # PID 1 是什么？→ systemd

# 老的运行级别（runlevel）在 systemd 中变成了 target
systemctl get-default                     # 当前默认的 target
systemctl list-units --type=target | grep runlevel
```

---

### 17.3 `kubelet` 中的 `-let` 后缀——"小代理"

`-let` 是英语中表示「小」的后缀（和 booklet、piglet、applet 一样）：

| 词根 | 含义 | +let | 含义 |
|------|------|------|------|
| pig | 猪 | pig**let** | 小猪 |
| book | 书 | book**let** | 小册子 |
| app | 应用 | app**let** | 小程序（Java Applet） |
| kube | K8s | kube**let** | K8s 在节点上的**小代理**——不是大脑，只是手脚 |

**kubelet 不是 Controller，它是 K8s 在每台机器上的执行者。** Controller 在大脑（control plane）里做决策，kubelet 在手脚（worker node）上执行。

---

### 17.4 `*/bin` `/sbin` `/usr/bin` `/usr/sbin` 中的目录名来源

| 目录 | 全称 | 里面的文件是 |
|------|------|-------------|
| `/bin` | **bin**aries（二进制文件） | 所有用户都能用的基础命令（`ls`, `cat`, `cp`） |
| `/sbin` | **s**ystem **bin**aries | 只有 root 才能用的系统管理命令（`fdisk`, `iptables`, `mkfs`） |
| `/usr/bin` | **U**nix **S**ystem **R**esources **bin**aries | 发行版安装的用户级可执行文件（`java`, `docker`, `kubectl`） |
| `/usr/sbin` | **usr** **s**ystem **bin**aries | 发行版安装的系统管理可执行文件 |
| `/usr/local/bin` | **local** 手动编译安装的 | 你自己装的软件（`helm`, `k3s`） |
| `/opt` | **opt**ional（可选的） | 大型第三方软件（`/opt/smart-invest/`） |

---

### 17.5 `etc` — 到底是什么意思？

`/etc` 目录名的来源有好几种说法，但最靠谱的是：

> **et cetera**（拉丁语「以及其他」/「等等」）——早期 Unix 开发者把「不知道放哪」的配置文件都扔进了 `/etc/`。

现在 `/etc` = **配置文件大全**。面试可能问到：

```bash
ls /etc  | head -20
# 你能看到几乎所有系统配置：
# /etc/hostname  — 主机名
# /etc/hosts     — 本地 DNS
# /etc/passwd    — 用户信息
# /etc/shadow    — 密码 hash
# /etc/fstab     — 开机自动挂载（FS TABle）
# /etc/ssh/      — SSH 配置
# /etc/systemd/  — systemd 服务配置
# /etc/apt/      — apt 软件源
```

---

### 17.6 `/proc` 和 `/sys` — 两个「假的」文件系统

| 目录 | 全称 | 本质 |
|------|------|------|
| `/proc` | **proc**ess（进程） | **伪文件系统**——只存在内存中，不占磁盘。内核通过它暴露进程和系统信息 |
| `/sys` | **sys**tem filesystem | **伪文件系统**——只存在内存中。比 `/proc` 更结构化，专门暴露内核和硬件信息 |

```bash
# 验证它们是「假的」
ls -l /proc/kcore        # 显示文件大小可能有 128TB（物理没那么多内存！）
                          # 因为它的内容由内核动态生成，不是真的存在磁盘上

# /proc 是只存在于内存的虚拟文件系统
df -h /proc
# Filesystem      Size  Used Avail Use% Mounted on
# proc               0     0     0    - /proc    ← Size=0！因为它不占磁盘
```

---

### 17.7 管道与重定向符号词源

| 符号 | 名字 | 含义来源 |
|------|------|----------|
| `|` | pipe（管道） | 来自流体力学——像水管一样，把左边命令的输出「引流」到右边命令 |
| `>` | redirect（覆盖） | 箭头方向 = 数据流向 |
| `>>` | redirect append（追加） | 两个箭头 = 追加不覆盖 |
| `2>&1` | stderr→stdout | `2` = stderr 的文件描述符编号，`1` = stdout 的编号 |
| `/dev/null` | null device | null = 「空」——写什么都消失，读什么都返回空 |

---

### 17.8 `rc` 后缀——例如 `.bashrc`、`/etc/rc.local`

**`rc` = `run commands`（运行命令）** 或 **`run control`（运行控制）**，来自早期 Unix 的 CTSS 操作系统传统。

| 文件 | 全称 | 作用 |
|------|------|------|
| `.bashrc` | Bash **R**un **C**ommands | 每个新 bash 窗口启动时自动执行的脚本 |
| `.vimrc` | Vim **R**un **C**ommands | Vim 启动时自动执行的配置 |
| `/etc/rc.local` | **R**un **C**ommands **Local** | 开机自启脚本（systemd 时代前的方法） |
| `init.rc` | **I**nit **R**un **C**ommands | init 进程的配置（Android 也有 `init.rc`） |

---

### 17.9 `sh` 后缀——Shell 脚本的扩展名

**`.sh` = Unix **Sh**ell。**

Shell 本身的含义是「壳」——相对于 Kernel（内核/核）。

```
Hardware → Kernel（内核/果仁） → Shell（外壳/命令行接口） → 用户
                                  ↑
                             包裹在内核外面的「壳」
                             用户通过 Shell 和 Kernel 交互
```

| 名字 | 含义 |
|------|------|
| **bash** | **B**ourne-**A**gain **Sh**ell——Bourne Shell（sh）的增强版。双关 "born again"（重生） |
| **zsh** | **Z** **Sh**ell——bash 的另一种增强版（macOS 默认 shell） |
| **sh** | Unix 上最原始的 **Sh**ell（Bourne Shell） |
| **ksh** | **K**orn **Sh**ell（David Korn 写的） |

---

### 17.10 DevOps 工具名缩写盘点

| 名字 | 全称 | 含义 |
|------|------|------|
| **K8s** | Kubernete**s** — 8 个字母省略 | K 和 s 之间省了 8 个字母 `ubernete` |
| **K3s** | K8s 砍一半 | 轻量级 K8s，把「8」换成「3」表示更小 |
| **etcd** | `/etc` distributed | Linux `/etc` 目录（配置）的分布式版本 |
| **apt** | **A**dvanced **P**ackage **T**ool | Debian 的高级包管理工具 |
| **yum** | **Y**ellowdog **U**pdater **M**odified | 最早为 Yellow Dog Linux 写的 |
| **LAMP** | **L**inux + **A**pache + **M**ySQL + **P**HP | 经典的 Web 应用技术栈缩写 |
| **MEAN** | **M**ongoDB + **E**xpress + **A**ngular + **N**ode.js | JavaScript 全栈缩写 |
| **SSH** | **S**ecure **Sh**ell | 加密的远程 Shell |
| **SSL** | **S**ecure **S**ockets **L**ayer | 已废弃（现在用 TLS），但名字还在用 |
| **TLS** | **T**ransport **L**ayer **S**ecurity | SSL 的继任者 |
| **HTTPS** | **H**yper**t**ext **T**ransfer **P**rotocol **S**ecure | HTTP + SSL/TLS |
| **API** | **A**pplication **P**rogramming **I**nterface | 两个系统之间的通信约定 |
| **POSIX** | **P**ortable **O**perating **S**ystem **I**nterface + **X**（Unix） | Unix 兼容标准——让不同 Unix 之间的代码可移植 |
| **GNU** | **G**NU's **N**ot **U**nix（递归缩写） | Richard Stallman 的自由软件项目。`ls`、`gcc` 都是 GNU 写的 |
| **WSL** | **W**indows **S**ubsystem for **L**inux | 在 Windows 里跑 Linux |
| **LTS** | **L**ong **T**erm **S**upport | 长期支持版本（Ubuntu LTS 有 5 年安全更新） |
| **lint** | 源自 Unix 的 **lint** 命令（见下方详解） | 静态代码检查工具，如 `helm lint`、`eslint`、`mvn checkstyle` |

**`lint` 的典故——「从毛衣上去掉小软毛」：**

`lint` 本来是一个 Unix 命令，由 Stephen C. Johnson 在 1979 年随 Unix V7 发布。现在泛指「静态检查」这一类工具。

根据权威的 **Jargon File**（黑客文化词典，由 Eric S. Raymond 等人维护）的记载：

> *"[lint is] named for the bits of fluff it supposedly picks from programs."*
>
> —— lint 得名于「它能从程序里挑出的小软毛/绒屑」

```
lint 的原义 = 织物表面沾的「小软毛 / 绒屑 / 线絮」

打个比方：你的黑裤子穿了几天会沾上白色的衣毛——那就是 lint。
在家用「粘毛器」来滚筒粘走它们，这个过程其实跟程序代码检查很像：
  → 代码里那些声明了却不用的变量、隐式类型转换、函数签名不匹配……
  → 它们不是编译器级别的「硬错误」（语法错误、链接错误），
     但累积起来会让程序「不干净」——就像 lint 在衣上积灰。
  → lint 这个工具就是「代码粘毛器」，把这些小毛刺一卷了之。
```

**源文献验证（可直接引用来面试）：**

| 源 | 内容 |
|----|------|
| **Jargon File (catb.org)** | "lint — named for the bits of fluff it supposedly picks from programs" |
| **Stephen C. Johnson, Bell Labs** | 1979 年在 Unix V7 中发布了 `lint(1)`，这是 C 语言静态分析工具的原型 |
| **FOLDOC (Free On-Line Dictionary of Computing)** | 同一定义 |

**今天你在 DevOps 工作中用到的 `lint` 后代：**

| 命令 | 全称/来源 | 检查什么 |
|------|-----------|----------|
| `helm lint` | Helm Lint | 检查 Helm Chart 的 YAML 语法和规范 |
| `hadolint` | Haskell Dockerfile Linter | 检查 Dockerfile 的坏习惯（如用 `latest` 标签、不以非 root 用户运行） |
| `eslint` | ECMAScript Linter | 检查 JavaScript/TypeScript 代码质量 |
| `shellcheck` | Shell Check | 检查 shell 脚本的常见错误（如忘记引号、`$?` 误用） |
| `terraform validate` | Terraform Validate | 检查 .tf 文件语法（Terraform 生态中的 lint） |

```bash
# 在你的 smart-invest 项目里跑一下 helm lint
cd infrastructure/helm-charts/umbrella
helm lint .
# 输出：
# ==> Linting .
# 1 chart(s) linted, 0 chart(s) failed
```

---

### 17.11 来自希腊神话的可观测性工具命名

| 工具 | 名字来源 | 含义 |
|------|----------|------|
| **Prometheus** | 普罗米修斯——希腊神话中盗火给人类的神 | 寓意「照亮黑暗」——Prometheus 把监控数据从黑箱中提取出来 |
| **Grafana** | Graph + -ana（后缀，表示关联） | 「图表相关的东西」 |
| **Jaeger** | 德语 Jäger = **H**unter（猎人） | 追猎分布式请求的调用链路 |
| **Istio** | 希腊语 ἰστίον = **sail**（帆） | 让微服务在网络之海中有方向地航行 |
| **Kiali** | 夏威夷语 = 晶莹/闪亮 | Istio 的可视化面板，「让服务网格变得清晰透明」 |

---

### 17.12 有趣的技术递归缩写

递归缩写是黑客文化的产物——名字本身就包含自己：

| 缩写 | 展开 |
|------|------|
| **GNU** | **G**NU's **N**ot **U**nix |
| **WINE** | **W**INE **I**s **N**ot an **E**mulator |
| **PHP** | **P**HP: **H**ypertext **P**reprocessor（最早叫 Personal Home Page） |
| **YAML** | **Y**AML **A**in't **M**arkup **L**anguage |
| **cURL** | **C**lient for **URL**s（最早叫 "see URL"，后来改名） |
| **npm** | **N**ode **P**ackage **M**anager（注意——官方说这不是递归缩写，但大家都这么说） |

---

### 17.13 一个带你穿越时间线的冷知识：为什么 `Ctrl+C` 是中断？

```
早年电传打字机（Teletype）时代：
  - Ctrl 键的作用是把字符的 ASCII 码的第 7 位和第 6 位清零
  - C 的 ASCII 码是 0x43（1000011）
  - Ctrl+C → 输出 0x03
  - 0x03 = ETX（End of Text，文本结束）字符
  - Unix 把这个解释为「中断当前进程」

同理：
  Ctrl+D → 0x04 = EOT（End of Transmission）= 「EOF / 退出」
  Ctrl+Z → 0x1A = SUB（Substitute）= 「暂停进程」
  Ctrl+\ → 0x1C = FS（File Separator）= 「SIGQUIT / 退出并 core dump」
```

---

> **这一章的要点：Linux/Unix 世界的命名不是随机的。每个名字都有一段历史和逻辑。当你理解了 `d` = daemon、`rc` = run commands、`/proc` = process pseudo-filesystem 时，你就不是「会敲命令」，而是「理解系统」。面试官能从你对这些术语的理解中看出你是不是真正在 Linux 环境里工作过。**

---

> **学习路线建议：**
>
> 1. **第一周**：第二章（FHS）+ 第四章（权限）+ 第一节（切换思维）。这三章能让你在任何 Linux 系统上不迷路。
> 2. **第二周**：第五章（进程信号）+ 第六章（Shell 脚本）。这两个是 DevOps 工作的基础。
> 3. **第三周**：第八章（systemd）+ 第十章（日志）+ 第十四章（SSH）。这三个是日常运维三板斧。
> 4. **持续练习**：第十六章（DevOps 场景），每天在工作中用一个场景。
>
> **面试时：** 面 DevOps 岗位时面试官可能随口问：
> - 「/etc 目录里有什么？」→ 配置文件
> - 「怎么看进程的环境变量？」→ `cat /proc/<pid>/environ`
> - 「服务器磁盘满了怎么查？」→ `df -h` → `du -h --max-depth=1` 逐层排查
> - 「chmod 755 是什么意思？」→ owner rwx，group r-x，others r-x
>
> 这些问题不考查你「会不会那个命令」，而是考查你「有没有在 Linux 上真实工作过」。
