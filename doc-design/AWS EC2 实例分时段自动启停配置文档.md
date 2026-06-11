**每天只在 8：00 至 12:00,14:00 至 18:00 之间启动实例，其他时候都停止实例**

下面是**严格按原文结构、排版还原**的纯 Markdown 格式，可直接复制粘贴到 `.md` 文件中使用：

---

根据AWS文档，您的需求（每天8:00-12:00和14:00-18:00运行实例）需要使用AWS Instance Scheduler解决方案，因为Quick Setup不支持一天内多个时间段的复杂调度。以下是详细的设置步骤：

## 方案选择
由于您需要每天两个不同的时间段（8:00-12:00和14:00-18:00），AWS Systems Manager Quick Setup无法满足此需求，因为它只支持简单的每日模式。我们需要使用AWS Instance Scheduler解决方案。

## 详细设置步骤

### 第一步：部署AWS Instance Scheduler
1. 访问AWS解决方案页面
   - 前往AWS Instance Scheduler解决方案
   - 点击"Launch in the AWS Console"
2. 部署CloudFormation模板
   - 选择您的区域
   - 配置参数：
     - Stack name: InstanceScheduler
     - Default timezone: Asia/Shanghai（或您的时区）
     - Tag name: Schedule
   - 点击"Create stack"

### 第二步：创建时间段（Periods）
部署完成后，需要在DynamoDB中创建两个时间段：

1. 访问DynamoDB控制台
   - 前往DynamoDB控制台
   - 找到名为ConfigTable的表
   - 点击"Explore table items"

2. 创建上午时间段
   - 点击"Create item"
   - 添加以下属性：
```json
{
  "type": "period",
  "name": "morning-hours",
  "description": "Morning working hours 8AM-12PM",
  "begintime": "08:00",
  "endtime": "12:00",
  "weekdays": ["mon-fri"]
}
```

3. 创建下午时间段
   - 再次点击"Create item"
   - 添加以下属性：
```json
{
  "type": "period",
  "name": "afternoon-hours",
  "description": "Afternoon working hours 2PM-6PM",
  "begintime": "14:00",
  "endtime": "18:00",
  "weekdays": ["mon-fri"]
}
```

### 第三步：创建调度计划（Schedule）
1. 在同一个DynamoDB表中创建调度计划
   - 点击"Create item"
   - 添加以下属性：
```json
{
  "type": "schedule",
  "name": "split-work-hours",
  "description": "Split working hours schedule",
  "periods": ["morning-hours", "afternoon-hours"],
  "timezone": "Asia/Shanghai"
}
```

### 第四步：标记EC2实例
1. 为实例添加标签
   - 前往EC2控制台
   - 选择要调度的实例
   - 点击"Tags"标签页
   - 添加标签：
     - Key: Schedule
     - Value: split-work-hours

### 第五步：使用CLI方式（推荐）
如果您更喜欢使用命令行，可以安装Scheduler CLI：

```bash
# 安装CLI
pip install scheduler-cli

# 创建上午时间段
scheduler-cli create-period --stack InstanceScheduler \
  --name morning-hours \
  --begintime 08:00 \
  --endtime 12:00 \
  --weekdays mon-fri

# 创建下午时间段
scheduler-cli create-period --stack InstanceScheduler \
  --name afternoon-hours \
  --begintime 14:00 \
  --endtime 18:00 \
  --weekdays mon-fri

# 创建调度计划
scheduler-cli create-schedule --stack InstanceScheduler \
  --name split-work-hours \
  --periods morning-hours,afternoon-hours \
  --timezone Asia/Shanghai
```

Run in CloudShell

### 第六步：验证配置
1. 检查调度状态
   - 使用CLI命令查看配置：
```bash
scheduler-cli describe-schedules --stack InstanceScheduler
scheduler-cli describe-periods --stack InstanceScheduler
```

2. 监控执行情况
   - 前往CloudWatch控制台
   - 查看Instance Scheduler的日志和指标

## 运行逻辑
配置完成后，您的实例将按以下时间表运行：
- 8:00 - 实例启动
- 12:00 - 实例停止
- 14:00 - 实例重新启动
- 18:00 - 实例停止
- 周末和节假日 - 实例保持停止状态

## 注意事项
1. 时区设置：确保时区设置正确，建议使用Asia/Shanghai
2. IAM权限：确保Instance Scheduler有足够权限管理EC2实例
3. 成本监控：可以在Cost Explorer中跟踪节省的成本
4. 测试验证：建议先在测试实例上验证调度是否按预期工作

这个解决方案将完全自动化您的实例管理，确保实例只在指定的工作时间运行，从而显著降低AWS成本。
---