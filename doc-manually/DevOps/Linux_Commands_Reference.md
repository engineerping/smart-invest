# Linux 常用命令速查手册（DevOps 工程师视角）

> 按使用频率从高到低排列，每个命令标注英文全称，每个参数标注含义。
> 以 smart-invest 项目日常运维为上下文。

---

## 目录

| 章节 | 类别 | 使用频率 |
|------|------|----------|
| 一 | 文件与目录操作 | ★★★★★ 每天几十次 |
| 二 | 文件查看与搜索 | ★★★★★ 每天几十次 |
| 三 | 文本处理 | ★★★★☆ 每天十几次 |
| 四 | 系统资源监控 | ★★★★☆ 每天若干次 |
| 五 | 进程管理 | ★★★☆☆ 排查时必用 |
| 六 | 网络排查 | ★★★☆☆ 排查时必用 |
| 七 | 权限与用户管理 | ★★★☆☆ 配置时常用 |
| 八 | 磁盘与存储 | ★★★☆☆ 巡检时常用 |
| 九 | 压缩与归档 | ★★☆☆☆ 运维操作时用 |
| 十 | 软件包管理 | ★★☆☆☆ 装软件时用 |
| 十一 | SSH 与远程操作 | ★★★★☆ 每天几十次 |
| 十二 | 定时任务 | ★★☆☆☆ 巡检脚本 |

---

## 一、文件与目录操作 / File & Directory Operations

### `ls` — list（列出目录内容）

**每天使用次数：100+**

```bash
ls [options] [path]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-l` | **l**ong | 长格式显示（权限、大小、时间、所有者） |
| `-a` | **a**ll | 显示所有文件，包括 `.` 开头的隐藏文件 |
| `-h` | **h**uman-readable | 文件大小显示为 K/M/G（人类可读） |
| `-t` | **t**ime | 按修改时间排序，最新的在前 |
| `-r` | **r**everse | 反转排序（配合 `-t` = 最旧在前） |
| `-S` | **S**ize | 按文件大小排序 |
| `-R` | **R**ecursive | 递归列出子目录 |
| `-d` | **d**irectory | 只显示目录本身，不展开内容 |
| `--color` | — | 按文件类型显示不同颜色 |

```bash
ls -lah              # 最常用组合：详细列表 + 隐藏文件 + 人类可读
ls -larth            # 同上 + 按时间排序 + 反转（看最近改的文件）
ls -lSrh             # 按大小排序，找大文件
```

---

### `cd` — change directory（切换目录）

**每天使用次数：100+**

```bash
cd [path]
```

| 参数 | 作用 |
|------|------|
| `cd` / `cd ~` | 回到 home 目录 |
| `cd -` | 回到上一个目录（反复切换时极好用） |
| `cd ..` | 回到上一级目录 |
| `cd /` | 回到根目录 |

```bash
cd -      # DevOps 最常用：在 K8s chart 目录和 scripts 目录之间反复跳
```

---

### `pwd` — print working directory（打印当前工作目录）

**每天使用次数：20+**

```bash
pwd            # /Users/gcsp/coding/claude_code_workspace/smart-invest
```

无参数，就是告诉你当前在哪。

---

### `mkdir` — make directory（创建目录）

```bash
mkdir [options] <dir>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-p` | **p**arents | 递归创建父目录（不存在也不报错） |

```bash
mkdir -p /opt/smart-invest/helm-charts/umbrella
# -p 保证整条路径一次性创建，不会因为父目录不存在而失败
```

---

### `cp` — copy（复制）

```bash
cp [options] <source> <destination>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-r` | **r**ecursive | 递归复制目录 |
| `-p` | **p**reserve | 保留权限、时间戳、所有者 |
| `-v` | **v**erbose | 显示复制过程 |
| `-u` | **u**pdate | 只在源文件更新时才覆盖 |
| `-a` | **a**rchive | 等同于 `-rp`，完整保留属性复制 |

```bash
cp -r ../charts ./umbrella/charts/              # 复制整个目录
cp -p ~/.kube/config ~/.kube/config.bak         # 备份且保留权限
```

---

### `mv` — move（移动/重命名）

```bash
mv [options] <source> <destination>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-v` | **v**erbose | 显示移动过程 |
| `-u` | **u**pdate | 只在源文件更新时才覆盖 |
| `-n` | **n**o-clobber | 不覆盖已存在的文件 |

```bash
mv old-chart.yaml Chart.yaml           # 重命名
mv *.tgz ../umbrella/charts/           # 批量移动
```

---

### `rm` — remove（删除）

```bash
rm [options] <target>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-r` | **r**ecursive | 递归删除目录 |
| `-f` | **f**orce | 强制删除，不提示确认 |
| `-i` | **i**nteractive | 每个文件都提示确认 |
| `-v` | **v**erbose | 显示删了什么 |

```bash
rm -rf ./charts/*.tgz              # CI 中清理旧依赖（危险！想清楚再敲）
rm -i *.yaml                       # 安全删除，每个都确认
```

---

### `touch` — touch（创建空文件 / 更新文件时间戳）

```bash
touch <file>
```

**作用：** 文件不存在则创建空文件；文件存在则更新其修改时间和访问时间为当前时间。

```bash
touch .gitkeep                    # 在空目录里放一个占位文件
touch /tmp/healthcheck            # 健康检查标记文件
```

---

### `ln` — link（创建链接）

```bash
ln [options] <source> <link>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-s` | **s**ymbolic | 创建软链接（符号链接） |
| `-f` | **f**orce | 强制覆盖已存在的链接 |

**软链接 vs 硬链接：**
| | 软链接 (symlink) | 硬链接 (hard link) |
|---|---|---|
| 本质 | 指向路径的指针 | 指向同一 inode |
| 跨文件系统 | ✓ | ✗ |
| 源文件删除后 | 链接失效（断链） | 仍然可访问 |
| 命令 | `ln -s` | `ln` |

```bash
ln -s /etc/rancher/k3s/k3s.yaml ~/.kube/config   # K3S kubeconfig 软链接
```

---

### `file` — file（判断文件类型）

```bash
file <target>
```

```bash
file app.jar                        # → Zip archive data (JAR)
file /usr/bin/kubectl               # → ELF 64-bit executable
file values.yaml                    # → ASCII text
file unknown.bin                    # 排查不明文件是什么
```

---

## 二、文件查看与搜索 / File Viewing & Searching

### `cat` — concatenate（连接并打印文件内容）

```bash
cat [options] <file>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-n` | **n**umber | 显示行号 |
| `-b` | **b**lank-skip | 显示行号但跳过空行 |
| `-A` | **A**ll | 显示所有不可见字符（`$` 表示行尾，`^I` 表示 tab） |

```bash
cat Chart.yaml                     # 快速看文件
cat file1.yaml file2.yaml > all.yaml  # 合并文件
cat -n deployment.yaml             # 看代码时带行号
```

---

### `less` — less（分页查看，more 的增强版）

```bash
less [options] <file>
```

**每天使用次数：50+**（比 `cat` 更常用，因为大文件你不会用 `cat`）

| 参数 | 全称 | 作用 |
|------|------|------|
| `-N` | **N**umber | 显示行号 |
| `-S` | **S**croll | 不自动换行（长行可以左右滚动） |
| `+F` | — | 类似 `tail -f`，持续追踪文件末尾 |
| `+G` | — | 跳到文件末尾 |
| `/pattern` | — | 搜索（n=下一个，N=上一个） |

```bash
less deployment.yaml               # 分页看
less -N -S application.log         # 带行号 + 长行不折行（看日志神器）
kubectl describe pod xxx | less    # 管道输出分页看
```

---

### `grep` — global regular expression print（全局正则搜索）

**每天使用次数：50+**（最常用的搜索命令）

```bash
grep [options] <pattern> [file...]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-r` | **r**ecursive | 递归搜索目录 |
| `-i` | **i**gnore-case | 忽略大小写 |
| `-v` | in**v**ert | 反选（显示不匹配的行） |
| `-n` | **n**umber | 显示行号 |
| `-l` | **l**ist | 只显示匹配的文件名 |
| `-c` | **c**ount | 显示匹配行数 |
| `-A N` | **A**fter N lines | 显示匹配行及之后 N 行 |
| `-B N` | **B**efore N lines | 显示匹配行及之前 N 行 |
| `-C N` | **C**ontext N lines | 显示匹配行前后各 N 行（最常用） |
| `-w` | **w**ord | 整词匹配（不会匹配到子串） |
| `-E` | **E**xtended regex | 使用扩展正则（支持 `|`、`+`、`?`） |
| `-o` | **o**nly-matching | 只输出匹配的部分 |
| `--color` | — | 高亮匹配词 |

```bash
grep -r "imagePullSecrets" ./helm-charts/                     # 递归搜代码
grep -i "error" application.log | tail -50                    # 看日志中的错误
grep -C 3 "OOMKilled" /var/log/kubelet.log                    # 看 OOM 上下文
kubectl get pods -A | grep -v Running                         # 反选：看异常 Pod
ps aux | grep java                                            # 找 Java 进程
grep -c "ERROR" application.log                               # 统计错误数量
```

---

### `find` — find（查找文件）

```bash
find <path> [expression]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-name` | **name** | 按文件名匹配（支持通配符，区分大小写） |
| `-iname` | **i**nsensitive-**name** | 按文件名匹配（不区分大小写） |
| `-type f` | **type f**ile | 只找普通文件 |
| `-type d` | **type d**irectory | 只找目录 |
| `-size` | **size** | 按文件大小 | `+100M`（大于 100M）`-1G`（小于 1G） |
| `-mtime` | **m**odification **time** | 按修改天数 | `-1`（1 天内改过）`+7`（7 天前改过） |
| `-mmin` | **m**odification **min**utes | 按修改分钟数 | `-60`（1 小时内改过） |
| `-user` | **user** | 按所有者查找 |
| `-perm` | **perm**ission | 按权限查找 |
| `-maxdepth N` | **max**imum **depth** | 最大递归深度（限制搜索范围） |
| `-exec` | **exec**ute | 对结果执行命令 |
| `-delete` | **delete** | 删除找到的文件 |

**`-exec` 用法（必须掌握）：**
```bash
find . -name "*.tgz" -exec rm {} \;        # 找到所有 .tgz 并删除
find . -name "*.yaml" -exec grep "image" {} +  # 在所有 yaml 中搜索 image
# {} = 占位符，代表找到的文件
# \; = 命令结束符（每个文件执行一次）
# +   = 批量传递（多个文件一次执行，性能更好）
```

**`-mtime` vs `-mmin` vs `-atime` vs `-ctime`：**
| 参数 | 含义 |
|------|------|
| `-atime` | **a**ccess time — 最后读取时间 |
| `-mtime` | **m**odification time — 最后修改内容时间 |
| `-ctime` | **c**hange time — 最后修改元数据（权限/所有者）时间 |
| `-mmin` | 同上，单位是分钟 |

```bash
# DevOps 常用场景
find /opt -name "*.log" -mtime +7 -delete               # 删除 7 天前的日志
find . -name "*.yaml" -type f                           # 找所有 yaml 文件
find /var/log -name "*.log" -size +100M                 # 找超大日志文件
find . -mmin -5                                          # 最近 5 分钟改过的文件
find ./charts -maxdepth 2 -name "values.yaml"            # 限制 2 层深度搜
find ./ -type f -name "*.tgz" -exec du -h {} \;          # 看每个 tgz 的大小
```

---

### `locate` — locate（从数据库快速查找文件）

```bash
locate [options] <pattern>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-i` | **i**gnore-case | 忽略大小写 |

**原理：** 不是实时搜索磁盘，而是搜索预建的数据库（updatedb）。比 `find` 快几十倍，但数据库不是实时的。

```bash
locate k3s.yaml                  # 秒出结果
sudo updatedb                    # 更新数据库（新文件才能被搜到）
```

---

### `head` — head（查看文件开头）

```bash
head [options] <file>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-n N` | **n**umber | 显示前 N 行（默认 10） |
| `-c N` | **c**haracter | 显示前 N 个字符 |

```bash
head -n 20 application.log       # 日志文件前 20 行
head -n 5 Chart.yaml             # 快速看 chart 头部元数据
```

---

### `tail` — tail（查看文件末尾）

```bash
tail [options] <file>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-n N` | **n**umber | 显示最后 N 行（默认 10） |
| `-f` | **f**ollow | 持续追踪文件末尾（实时看日志，Ctrl+C 退出） |
| `-F` | **F**ollow（retry） | 同 `-f`，但文件被删除/轮转后自动重新打开 |
| `-c N` | **c**haracter | 显示最后 N 个字符 |

```bash
# DevOps 最常用的三个 tail 场景
tail -f /var/log/syslog                      # 实时追踪系统日志
tail -F /var/log/app.log                     # 追踪 + 自动处理日志轮转
tail -n 100 app.log | grep ERROR             # 最近 100 行中的错误
```

---

### `wc` — word count（统计字数/行数）

```bash
wc [options] <file>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-l` | **l**ines | 统计行数 |
| `-w` | **w**ords | 统计单词数 |
| `-c` | **c**haracters | 统计字符数 |

```bash
kubectl get pods -A | wc -l             # 集群有多少个 Pod
grep -r "TODO" ./src | wc -l            # 有多少 TODO
find . -name "*.java" | wc -l           # 代码库有多少 Java 文件
```

---

### `sort` — sort（排序）

```bash
sort [options] <file>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-n` | **n**umeric | 按数值排序（而不是字典序） |
| `-r` | **r**everse | 降序 |
| `-u` | **u**nique | 去重 |
| `-k N` | **k**ey | 按第 N 列排序 |
| `-t` | separa**t**or | 指定分隔符（默认空格/tab） |
| `-h` | **h**uman-numeric | 识别 K/M/G 单位排序 |

```bash
du -sh * | sort -hr                     # 看哪个目录最大（按人类可读排序）
kubectl get pods | sort -k5              # 按 Pod 运行时长排序
ps aux | sort -k3 -nr | head -10        # 按 CPU 占用排序，取前 10
```

---

### `uniq` — unique（去重/统计重复）

```bash
uniq [options] <file>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-c` | **c**ount | 每行前面显示出现次数 |
| `-d` | **d**uplicates | 只显示重复的行 |
| `-u` | **u**nique | 只显示不重复的行 |

**注意：** `uniq` 只对**相邻的**重复行去重，通常先 `sort` 再 `uniq`。

```bash
sort access.log | uniq -c | sort -nr     # 统计每种日志出现次数
sort ips.txt | uniq -c | sort -nr | head -10  # Top 10 访问 IP
```

---

## 三、文本处理 / Text Processing

### `sed` — stream editor（流编辑器，替换/删除/插入）

```bash
sed [options] '<command>' <file>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-i` | **i**n-place | 原地修改文件（不加 `-i` 只输出到屏幕） |
| `-i.bak` | — | 原地修改，但先备份为 `.bak` 文件 |
| `-e` | **e**xpression | 指定一个编辑命令（多个命令时用） |
| `-n` | — | 抑制默认输出（配合 `p` 命令只打印匹配行） |
| `s/old/new/` | **s**ubstitute | 替换（最常用） |
| `/pattern/d` | **d**elete | 删除匹配行 |
| `/pattern/p` | **p**rint | 打印匹配行（配合 `-n`） |

**替换 flags（写在 `s/old/new/` 末尾）：**

| flag | 含义 |
|------|------|
| `g` | **g**lobal — 替换每一行的所有匹配（不带 g 只替换每行第一个） |
| `i` | **i**gnore case — 不区分大小写 |
| `数字` | 只替换每行第 N 个匹配 |
| `p` | 替换的同时打印出来 |

```bash
# DevOps 最常用场景
sed -i 's/v1/v2/g' values.yaml                         # 全局替换镜像版本
sed -i 's/http:/https:/g' *.yaml                       # 替换所有 yaml 中的协议
sed -i.bak 's/localhost/192.168.31.192/g' values.yaml  # 替换 + 备份原文件
sed -n '10,20p' deployment.yaml                        # 打印 10-20 行
sed -i '/DEBUG/d' application.log                      # 删除包含 DEBUG 的行
sed 's/^/  /' file                                     # 每行前加 2 空格（缩进）
```

---

### `awk` — Aho, Weinberger, Kernighan（三位作者姓氏）

```bash
awk [options] '<pattern> { <action> }' <file>
```

**核心概念：** awk 按行读取文件 → 自动切分成列（`$1 $2 $3...`） → 执行你写的动作。

| 内置变量 | 全称 | 含义 |
|----------|------|------|
| `$0` | — | 整行 |
| `$1 $2 ...` | — | 第 1, 2, ... 列 |
| `$NF` | Number of Fields | 最后一列 |
| `$(NF-1)` | — | 倒数第二列 |
| `NR` | Number of Records | 当前行号 |
| `NF` | Number of Fields | 当前行列数 |
| `-F` | **F**ield separator | 指定分隔符（默认空格/tab） |

```bash
# 打印指定列
kubectl get pods -A | awk '{print $1, $2}'                # namespace + pod 名
ps aux | awk '{print $2, $3, $11}'                        # PID, CPU%, 进程名

# 带条件过滤
kubectl get pods -A | awk '$4 != "Running" {print $0}'    # 只看非 Running Pod
df -h | awk '$5 > 80 {print $0}'                          # 看使用率 > 80% 的磁盘
du -sh * | awk '$1 ~ /G/ {print $0}'                      # 看大于 1G 的目录

# 统计
kubectl get pods | awk '{sum+=$4} END {print sum}'        # 统计重启次数之和

# 切割日志
awk -F'"' '{print $6}' access.log | sort | uniq -c        # 统计 HTTP 状态码
```

---

### `cut` — cut（按列切割）

```bash
cut [options] <file>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-d` | **d**elimiter | 指定分隔符 |
| `-f N` | **f**ield | 取第 N 列 |
| `-c N-M` | **c**haracter | 取第 N 到 M 个字符 |

```bash
cut -d':' -f1 /etc/passwd                             # 列出所有用户名
cat Chart.yaml | grep name | cut -d':' -f2             # 取 chart 名称
echo "192.168.31.192" | cut -d'.' -f1-3               # → 192.168.31
```

---

### `diff` — difference（比较两个文件的差异）

```bash
diff [options] <file1> <file2>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-u` | **u**nified | 统一格式输出（像 git diff） |
| `-r` | **r**ecursive | 递归比较目录 |
| `-q` | **q**uiet | 只报告文件是否不同 |
| `-w` | **w**hitespace | 忽略空格差异 |
| `-y` | side-b**y**-side | 并排显示 |

```bash
diff -u values-dev.yaml values-prod.yaml                   # 看环境配置差异
helm template smart-invest . -f values-prod.yaml > /tmp/current.yaml
helm template smart-invest . -f values-prod.yaml --set image.tag=v2 > /tmp/new.yaml
diff -u /tmp/current.yaml /tmp/new.yaml                     # 面试重点：部署前 diff
```

---

### `tee` — tee（T 形分流：同时输出到屏幕和文件）

```bash
command | tee [options] <file>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-a` | **a**ppend | 追加而不是覆盖 |

```bash
helm install smart-invest . 2>&1 | tee install.log        # 看输出同时保存到文件
./deploy.sh 2>&1 | tee -a /var/log/deploy.log             # 追加记录部署日志
```

---

## 四、系统资源监控 / System Resource Monitoring

### `top` / `htop` — table of processes（进程表）

```bash
top [options]
```

| 参数/快捷键 | 作用 |
|-------------|------|
| `-c` | 显示完整命令行 |
| `-u <user>` | 只看指定用户的进程 |
| `-p <pid>` | 只看指定 PID |
| `1` | 显示每个 CPU 核心 |
| `k` | 杀死进程（输入 PID） |
| `M` | 按内存排序 |
| `P` | 按 CPU 排序（默认） |

**top 输出关键指标：**

| 指标 | 含义 | 排查关注点 |
|------|------|-----------|
| `load average` | 1/5/15 分钟平均负载 | > CPU 核心数 = 过载 |
| `%Cpu(s): us` | user CPU 时间 | 应用本身花费的 CPU |
| `%Cpu(s): sy` | system CPU 时间 | 内核花费的 CPU，过高 → 太多系统调用 |
| `%Cpu(s): wa` | iowait | 等待磁盘 IO，持续高 = 磁盘瓶颈 |
| `RES` | 实际物理内存使用 | Pod 的 memory limit 根据这个设 |

```bash
top -c                              # 看进程完整命令
top -u george                       # 只看 george 用户的进程
```

`htop` 是 `top` 的增强版，彩色、可用鼠标、支持滚动，大多数服务器需要 `apt install htop`。

---

### `free` — free（内存使用情况）

```bash
free [options]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-h` | **h**uman-readable | 人类可读单位 |
| `-m` | **m**egabytes | 单位 MB |
| `-g` | **g**igabytes | 单位 GB |
| `-s N` | **s**leep | 每 N 秒刷新一次 |

**输出关键指标：**

| 指标 | 含义 | Kubernetes 关联 |
|------|------|----------------|
| `total` | 总内存 | 节点 allocatable memory |
| `used` | 已用 | Pod 的 requests/limits 消耗 |
| `free` | 空闲 | 可分配给新 Pod |
| `available` | 可用（含 buffer/cache 可回收部分） | **这个才是真正可用的内存** |
| `buff/cache` | 文件系统缓存 | Linux 会尽可能用空闲内存做缓存 |

```bash
free -h                            # K3S 节点巡检必查
free -h -s 2                       # 每 2 秒刷一次
```

---

### `df` — disk free（磁盘空间）

```bash
df [options] [path]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-h` | **h**uman-readable | 人类可读 |
| `-T` | **T**ype | 显示文件系统类型 |
| `-i` | **i**nodes | 显示 inode 使用情况（文件数限制） |
| `-x` | e**x**clude | 排除指定文件系统类型 |

```bash
df -h                              # 看所有挂载点的空间
df -h /var/lib/kubelet             # 看 K3S 数据目录的空间
df -i                              # 看 inode 是否用完（小文件太多也会爆）
```

---

### `du` — disk usage（目录/文件占用空间）

```bash
du [options] [path]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-h` | **h**uman-readable | 人类可读 |
| `-s` | **s**ummarize | 只显示总计 |
| `-d N` | **d**epth | 递归深度 |
| `--max-depth=N` | — | 同上 |
| `-a` | **a**ll | 显示文件（不仅目录） |

```bash
du -sh /opt/smart-invest              # 项目占了多大空间
du -sh * | sort -hr                   # 当前目录下谁最大
du -h --max-depth=1 /var/log          # /var/log 下各子目录大小

# 排查磁盘满了
du -h --max-depth=1 / | sort -hr | head -10   # 找根目录下谁占空间最多
```

---

### `uptime` — uptime（系统运行时间 + 负载）

```bash
uptime
```

**输出示例：** `14:30:00 up 30 days, 2:15, 3 users, load average: 0.08, 0.15, 0.22`

| 字段 | 含义 |
|------|------|
| `up 30 days` | 运行了 30 天 |
| `3 users` | 当前登录用户数 |
| `load average: 0.08, 0.15, 0.22` | 1/5/15 分钟平均负载 |

**Load Average 解读：**
- 值 < CPU 核心数 = 正常
- 值 ≈ CPU 核心数 = 满载
- 值 > CPU 核心数 = 过载，有进程在排队等 CPU

```bash
nproc                          # 先看有几个 CPU 核心
uptime                         # 再看负载有没有超过核心数
```

---

### `vmstat` — virtual memory statistics（虚拟内存统计）

```bash
vmstat [interval] [count]
```

| 列 | 含义 |
|----|------|
| `r` | run queue — 等待 CPU 的进程数 |
| `b` | blocked — 等待 IO 的进程数 |
| `swpd` | 使用的 swap |
| `si/so` | swap in / swap out — >0 说明内存不够了，严重！ |
| `us/sy/id/wa` | user/system/idle/wait 时间 |

```bash
vmstat 2 5                       # 每 2 秒输出一次，共 5 次
vmstat 1                          # 每 1 秒输出，一直输出
```

---

### `iostat` — I/O statistics（磁盘 IO 统计）

```bash
iostat [options] [interval]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-x` | e**x**tended | 扩展统计（含 await, %util） |
| `-d` | **d**evice | 只显示磁盘 |
| `-m` | **m**egabytes | 单位 MB |

```bash
iostat -x 2                       # 每 2 秒看磁盘 IO，排查磁盘瓶颈
```

**关键列解读：**

| 列 | 含义 | 阈值 |
|----|------|------|
| `%util` | 磁盘繁忙时间占比 | > 80% = 磁盘瓶颈 |
| `await` | 每个 IO 请求的平均等待时间(ms) | > 20ms = 慢 |
| `svctm` | 每个 IO 请求的服务时间(ms) | — |

---

### `lsof` — list open files（列出打开的文件）

```bash
lsof [options]
```

| 参数 | 作用 |
|------|------|
| `-i :port` | 看哪个进程占用这个端口 |
| `-p <pid>` | 看指定进程打开了哪些文件 |
| `-u <user>` | 看指定用户打开的文件 |
| `<file>` | 看谁打开了这个文件 |

```bash
lsof -i :8080                       # 谁在用 8080 端口（端口冲突排查）
lsof -i :6443                       # K3S API Server 端口
lsof -u george                      # george 用户打开了什么
lsof /var/log/syslog               # 谁在写这个文件
```

---

### `ss` — socket statistics（socket 统计，netstat 的替代品）

```bash
ss [options]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-t` | **t**cp | 只显示 TCP |
| `-u` | **u**dp | 只显示 UDP |
| `-l` | **l**istening | 监听中的端口 |
| `-p` | **p**rocess | 显示进程名 |
| `-n` | **n**umeric | 不解析主机名/服务名（更快） |
| `-a` | **a**ll | 所有 socket（含 LISTEN + ESTABLISHED） |
| `-s` | **s**ummary | 统计摘要 |

```bash
ss -tlnp                        # 看所有 TCP 监听端口及进程（DevOps 最常用）
ss -tnp | grep ESTAB            # 看活跃连接
ss -s                           # socket 统计概览
```

---

## 五、进程管理 / Process Management

### `ps` — process status（进程状态）

```bash
ps [options]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `aux` | **a**ll / **u**ser / e**x**ecute | BSD 风格：所有用户的所有进程 + 详细信息 |
| `-ef` | **e**very /**f**ull | Unix 风格：所有进程 + 完整命令行 |

```bash
# DevOps 最常用的两个
ps aux | grep java                   # 找 Java 进程
ps -ef | grep k3s                    # 找 K3S 进程

# 按内存/CPU 排序
ps aux --sort=-%mem | head -10       # Top 10 内存占用
ps aux --sort=-%cpu | head -10       # Top 10 CPU 占用
```

**ps aux 列含义：**

| 列 | 全称 | 含义 |
|----|------|------|
| USER | — | 进程所有者 |
| PID | Process ID | 进程 ID |
| %CPU | — | CPU 使用百分比 |
| %MEM | — | 内存使用百分比 |
| VSZ | Virtual SiZe | 虚拟内存大小(KB) |
| RSS | Resident Set Size | 实际物理内存(KB) |
| STAT | State | 进程状态码 |
| START | — | 启动时间 |
| TIME | — | 累计 CPU 时间 |

**STAT 状态码：**
| 码 | 含义 |
|----|------|
| R | **R**unning — 正在运行或可运行 |
| S | **S**leeping — 可中断睡眠（等待事件） |
| D | **D**isk sleep — 不可中断睡眠（等待 IO，kill -9 也杀不掉！） |
| Z | **Z**ombie — 僵尸进程（已死但父进程没 wait） |
| T | S**t**opped — 被信号暂停 |

---

### `kill` — kill（发送信号给进程）

```bash
kill [signal] <pid>
```

| 信号 | 编号 | 含义 |
|------|------|------|
| SIGTERM | 15 | **Term**ination — 优雅终止（K8s 默认先发这个） |
| SIGKILL | 9 | **Kill** — 强制终止（K8s terminationGracePeriod 超时后发这个） |
| SIGHUP | 1 | **H**ang**U**p — 重新加载配置（常用来 reload） |
| SIGINT | 2 | **Int**errupt — 等同于 Ctrl+C |
| SIGQUIT | 3 | **Quit** — 退出并 core dump |

```bash
kill -15 12345                       # 优雅终止进程 12345
kill -9 12345                        # 强制杀（只在 -15 无效时用）
kill -1 12345                        # 让进程重读配置文件
pkill -f "java.*user-service"        # 按名字杀进程
killall nginx                        # 杀掉所有同名进程
```

---

### `nohup` — no hangup（忽略挂断信号，后台持续运行）

```bash
nohup <command> &
```

```bash
nohup ./deploy.sh > deploy.log 2>&1 &    # 后台部署，退出 SSH 也不中断
```

---

### `jobs` / `bg` / `fg` — 作业控制

```bash
jobs                    # 列出当前 shell 的后台作业
bg %1                   # 把作业 1 放到后台运行
fg %1                   # 把作业 1 拉回前台
Ctrl+Z                  # 暂停当前作业
```

---

## 六、网络排查 / Network Troubleshooting

### `curl` — client URL（HTTP 客户端）

```bash
curl [options] <url>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-v` | **v**erbose | 详细输出（含请求头、响应头、SSL 握手过程） |
| `-s` | **s**ilent | 安静模式，不显示进度条 |
| `-o` | **o**utput file | 保存到文件 |
| `-O` | **O**riginal name | 用远程文件名保存 |
| `-I` | — | 只获取响应头（HEAD 请求） |
| `-X` | — | 指定 HTTP 方法 | `-X POST`, `-X DELETE` |
| `-H` | **H**eader | 添加请求头 | `-H "Authorization: Bearer token"` |
| `-d` | **d**ata | POST 数据 | `-d '{"key":"value"}'` |
| `-k` | insec**k**ure | 跳过 SSL 证书验证 |
| `-L` | **L**ocation | 跟随重定向 |
| `-w` | **w**rite-out | 输出格式化的响应信息 |
| `--connect-timeout` | — | 连接超时时间（秒） |
| `-u` | **u**ser | 带认证：`-u user:password` |

```bash
# DevOps 排查常用
curl -v https://192.168.31.192/api/health                   # 详细排查
curl -I https://example.com                                  # 只看响应头
curl -s -o /dev/null -w "%{http_code}" https://example.com   # 只输出 HTTP 状态码
curl -k https://localhost:6443/healthz                       # K3S API Server 健康检查
curl -X POST -H "Content-Type: application/json" -d '{}' http://api/test
```

---

### `ping` — packet internet groper（ICMP 连通性测试）

```bash
ping [options] <host>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-c N` | **c**ount | 发 N 个包后停止 |
| `-i N` | **i**nterval | 间隔 N 秒 |
| `-W N` | deadline **W** | 超时 N 秒 |

```bash
ping -c 4 192.168.31.192                              # 测 4 次就停
```

---

### `nslookup` / `dig` — DNS 查询

```bash
nslookup [options] <domain>
dig [options] <domain> <type>
```

```bash
# K8S 内部 DNS 排查（进 debug Pod 后）
nslookup user-service.smart-invest.svc.cluster.local
dig +short api-gateway.smart-invest.svc.cluster.local

# 外网 DNS
nslookup github.com
dig github.com A                                    # 查 A 记录
dig github.com MX                                   # 查 MX 记录
```

---

### `nc` — netcat（TCP/UDP 瑞士军刀）

```bash
nc [options] <host> <port>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-v` | **v**erbose | 详细输出 |
| `-z` | **z**ero-I/O | 只测试连接，不发送数据（端口扫描） |
| `-l` | **l**isten | 监听模式 |
| `-w N` | time**w**ait | 超时 N 秒 |
| `-u` | **U**DP | UDP 模式 |

```bash
nc -zv 192.168.31.192 6443              # K3S API Server 端口测通
nc -zv 192.168.31.192 22                # SSH 端口测通
nc -zv -w 3 db-host 5432                # PostgreSQL 端口测试（3 秒超时）
```

---

### `telnet` — teletype network（端口连通性测试，老牌工具）

```bash
telnet <host> <port>
```

```bash
telnet 192.168.31.192 80               # 测 HTTP 端口
# 如果通：显示 Connected；如果不通：Connection refused 或 timeout
```

现在更推荐用 `nc -zv`，但 `telnet` 依然广泛存在于面试题中。

---

### `traceroute` — trace route（路由追踪）

```bash
traceroute <host>
```

```bash
traceroute github.com                   # 看经过了多少跳
```

---

### `wget` — web get（下载文件）

```bash
wget [options] <url>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-O` | **O**utput | 指定输出文件名 |
| `-c` | **c**ontinue | 断点续传 |
| `-q` | **q**uiet | 安静模式 |
| `--no-check-certificate` | — | 跳过 SSL 证书检查 |

```bash
wget -O install.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
```

---

## 七、权限与用户管理 / Permission & User Management

### `chmod` — change mode（修改文件权限）

```bash
chmod [options] <mode> <target>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-R` | **R**ecursive | 递归应用到子目录 |

**两种写法：**

| 写法 | 示例 | 含义 |
|------|------|------|
| 符号 | `u+x` / `g-w` / `o=r` | u=owner / g=group / o=others；+加权限 / -减权限 / =精确设置 |
| 八进制 | `755` / `644` / `600` | r=4, w=2, x=1，三位分别代表 u/g/o |

```bash
chmod +x deploy.sh                          # 给脚本加执行权限
chmod 755 /opt/smart-invest/deploy.sh       # rwxr-xr-x
chmod 600 ~/.ssh/id_rsa                     # 私钥只有自己可读写
chmod -R 755 /opt/myapp                     # 递归
```

---

### `chown` — change owner（修改文件所有者）

```bash
chown [options] <user>:<group> <target>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-R` | **R**ecursive | 递归 |

```bash
chown george:george values.yaml             # 改成 george 用户和组
chown -R 1000:1000 /data                    # 容器常用的 UID:GID
```

---

### `sudo` — superuser do（以超级用户身份执行）

```bash
sudo [options] <command>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-i` | **i**nteractive | 以 root 登录 |
| `-u <user>` | **u**ser | 以指定用户身份执行 |
| `-E` | **E**nvironment | 保留当前环境变量 |

```bash
sudo helm upgrade --install smart-invest . -n smart-invest
sudo -u postgres psql -c "SELECT 1"         # 以 postgres 用户执行
```

---

### `whoami` / `id` / `groups` — 查看当前用户身份

```bash
whoami                    # 当前用户名 → george
id                        # 当前用户 UID、GID、所属组
groups                    # 当前用户所属的所有组
```

---

## 八、磁盘与存储 / Disk & Storage

### `mount` / `umount` — 挂载/卸载文件系统

```bash
mount [options] <device> <mountpoint>
umount <mountpoint>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-t` | **t**ype | 指定文件系统类型 | `-t nfs`, `-t ext4` |
| `-o` | **o**ptions | 挂载选项 | `-o rw,noatime` |

```bash
mount                                   # 列出所有挂载
mount /dev/sdb1 /mnt/data               # 挂载
umount /mnt/data                        # 卸载
umount -l /mnt/data                     # 懒卸载（lazy：等没人用了再卸）
```

---

### `lsblk` — list block devices（列出块设备）

```bash
lsblk [options]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-f` | **f**ilesystem | 显示文件系统类型和 UUID |
| `-m` | **m**ode | 显示权限模式 |

```bash
lsblk                                   # 看所有磁盘和分区
lsblk -f                                # 看文件系统类型
```

---

### `blkid` — block ID（查看块设备 UUID 和类型）

```bash
blkid                                   # 显示所有块设备的 UUID 和文件系统类型
```

---

### `fdisk` — format disk（分区管理）

```bash
fdisk -l                    # 列出所有磁盘和分区表（需要 root）
```

---

### `dd` — disk dump（磁盘复制/创建文件）

```bash
dd if=<input> of=<output> [options]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `if` | **i**nput **f**ile | 输入文件/设备 |
| `of` | **o**utput **f**ile | 输出文件/设备 |
| `bs` | **b**lock **s**ize | 块大小 |
| `count` | — | 块数量 |
| `status=progress` | — | 显示进度 |

```bash
dd if=/dev/sda of=/backup/mbr.bak bs=512 count=1            # 备份 MBR
dd if=/dev/zero of=/swapfile bs=1M count=4096               # 创建 4G swap 文件
```

---

## 九、压缩与归档 / Compression & Archiving

### `tar` — tape archive（打包/解包）

```bash
tar [options] [target] [files...]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-c` | **c**reate | 创建归档 |
| `-x` | e**x**tract | 解包 |
| `-f` | **f**ile | 指定文件名（必须！） |
| `-v` | **v**erbose | 显示过程 |
| `-z` | g**z**ip | 用 gzip 压缩/解压 |
| `-j` | — | 用 bzip2 压缩/解压 |
| `-C` | **C**hange dir | 解压到指定目录 |
| `-t` | **t**est/list | 查看包内容 |

```bash
# DevOps 最常用
tar -czvf charts.tar.gz ./charts/                       # 打包 + gzip 压缩
tar -xzvf charts.tar.gz                                 # 解压
tar -xzvf helm-v3.14.0-linux-amd64.tar.gz -C /usr/local/bin   # 解压到指定目录
tar -tzvf charts.tar.gz                                 # 看包里有什么（不解压）
```

---

### `gzip` / `gunzip` — GNU zip（压缩/解压）

```bash
gzip <file>                      # 压缩（原文件会被替换为 .gz）
gunzip <file>.gz                 # 解压
gzip -d <file>.gz                # 同上
```

---

### `zip` / `unzip` — ZIP 格式

```bash
zip -r output.zip dir/           # 递归压缩目录
unzip archive.zip -d /target/    # 解压到指定目录
unzip -l archive.zip             # 只看内容不解压
```

---

## 十、软件包管理 / Package Management

### `apt` — advanced package tool（Debian/Ubuntu）

```bash
apt update                    # 更新软件包索引
apt upgrade                   # 升级所有可升级的包
apt install <package>         # 安装
apt remove <package>          # 卸载（保留配置文件）
apt purge <package>           # 彻底卸载（删配置文件）
apt search <keyword>          # 搜索包
apt list --installed          # 列出已安装的包
apt autoremove                # 删除不再需要的依赖
```

### `yum` / `dnf` — Yellowdog Updater Modified（RHEL/CentOS）

```bash
yum install <package>         # 安装
yum remove <package>          # 卸载
yum update                    # 更新所有
yum search <keyword>          # 搜索
```

---

## 十一、SSH 与远程操作 / SSH & Remote

### `ssh` — secure shell

```bash
ssh <user>@<host> [options]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-p` | **p**ort | 指定端口（默认22） |
| `-i` | **i**dentity | 指定私钥文件 |
| `-L` | **L**ocal forward | 本地端口转发 |
| `-R` | **R**emote forward | 远程端口转发 |
| `-o StrictHostKeyChecking=no` | — | 跳过首次连接确认 |

```bash
ssh george@192.168.31.192                                   # 日常 SSH
ssh -i ~/.ssh/id_rsa george@192.168.31.192                  # 指定私钥
ssh george@192.168.31.192 "kubectl get pods -n smart-invest"  # 远程执行命令
```

---

### `scp` — secure copy（SSH 协议传文件）

```bash
scp [options] <source> <destination>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-r` | **r**ecursive | 递归传输目录 |
| `-P` | **P**ort | 指定端口 |
| `-q` | **q**uiet | 安静模式 |
| `-C` | **C**ompress | 压缩传输 |

```bash
scp values.yaml george@192.168.31.192:/opt/smart-invest/        # 上传
scp -r ./charts george@192.168.31.192:/opt/smart-invest/        # 上传目录
scp george@192.168.31.192:/var/log/syslog ./                    # 下载
```

---

### `rsync` — remote sync（增量同步，比 scp 更智能）

```bash
rsync [options] <source> <destination>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-a` | **a**rchive | 归档模式（等同于 -rlptgoD） |
| `-v` | **v**erbose | 详细 |
| `-z` | **z**ip | 压缩传输 |
| `-P` | **P**rogress | 显示进度 + 支持断点续传 |
| `--delete` | — | 删除目标中存在但源中不存在的文件 |
| `--exclude` | — | 排除指定模式 |
| `-n` | dr**y** ru**n** | 试运行（看看会同步什么，不真做） |

```bash
# DevOps 最常用：同步 chart 目录到服务器
rsync -avzP ./helm-charts/ george@192.168.31.192:/opt/smart-invest/helm-charts/

# 试运行
rsync -avzn ./charts/ server:/opt/charts/

# 同步 + 删除多余文件
rsync -avz --delete ./dist/ server:/var/www/html/
```

---

### `sshpass` — SSH password（非交互式密码传参，脚本用）

| 参数 | 作用 |
|------|------|
| `-p` | 指定密码 |

```bash
# 你的项目脚本中实际在用的
sshpass -p 'George0' ssh george@192.168.31.192 "hostname"
sshpass -p 'George0' scp -r ./charts george@192.168.31.192:/tmp/
```

---

## 十二、定时任务 / Scheduled Tasks

### `crontab` — cron table（定时任务）

```bash
crontab [options]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-l` | **l**ist | 列出当前用户的定时任务 |
| `-e` | **e**dit | 编辑定时任务 |
| `-r` | **r**emove | 删除所有定时任务 |

**Cron 表达式（5 字段）：**
```
分钟 小时 日期 月份 星期
 0    9    *    *    1-5       = 每个工作日 9:00
*/5   *    *    *    *         = 每 5 分钟
30    2    *    *    0         = 每周日凌晨 2:30
```

```bash
crontab -e
# 每天凌晨 3 点清理 7 天前的日志
0 3 * * * find /var/log -name "*.log" -mtime +7 -delete
```

---

## 附录：管道与重定向 / Pipes & Redirection

### 核心概念

| 符号 | 全称/含义 | 作用 |
|------|-----------|------|
| `\|` | pipe（管道） | 把左边命令的 stdout 传给右边命令的 stdin |
| `>` | redirect（覆盖重定向） | 把 stdout 写入文件（覆盖） |
| `>>` | redirect append（追加重定向） | 把 stdout 写入文件（追加） |
| `<` | input redirect（输入重定向） | 从文件读取 stdin |
| `2>&1` | stderr → stdout | 把 stderr 合并到 stdout |
| `&>` | — | 同时重定向 stdout 和 stderr（等价于 `> file 2>&1`） |
| `/dev/null` | 黑洞设备 | 丢弃所有写入它的数据 |

**文件描述符：**
| 编号 | 含义 |
|------|------|
| `0` | stdin（标准输入） |
| `1` | stdout（标准输出） |
| `2` | stderr（标准错误） |

```bash
# 场景 1：保存部署日志（stdout + stderr 都存下来）
helm upgrade --install smart-invest . 2>&1 | tee deploy.log

# 场景 2：后台运行 + 丢弃输出
./script.sh > /dev/null 2>&1 &

# 场景 3：只看 stderr
command 2>&1 >/dev/null | grep ERROR

# 场景 4：管道链 —— DevOps 最常见
kubectl get pods -A | grep -v Running | awk '{print $2}' | xargs kubectl describe pod
```

---

> **DevOps 面试中体现 Linux 熟练度的关键：**
> 1. 能用管道把 3-4 个命令串起来完成一个排查任务
> 2. 知道 `2>&1` 是什么意思（stderr 合并到 stdout）
> 3. `find ... -exec` 和 `grep -r` 是查找的左右手
> 4. `ss -tlnp` 比 `netstat` 更快更现代
> 5. `df -h` / `du -sh` / `free -h` 是巡检三板斧
> 6. `curl -v` / `nc -zv` / `ping -c` 是网络排查三件套
> 7. `kubectl logs --previous` + `kubectl describe` 是 K8s 排查二连——这说明你真正在生产环境排查过问题
