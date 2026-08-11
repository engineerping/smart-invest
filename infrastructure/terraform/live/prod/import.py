#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ═══════════════════════════════════════════════════════════════════════════════
# Terraform Import 脚本 —— 将已存在的 AWS 资源导入 Terraform 管理
# ═══════════════════════════════════════════════════════════════════════════════
# 原 import.sh 因 shell proxy/SSL 环境问题不可靠，已重写为 Python 版本。
#
# 使用方式：
#   cd infrastructure/terraform/live/prod
#   python3 import.py
#
# 前置条件：
#   1. terraform.tfvars 已配置
#   2. terraform init 已完成
#   3. AWS 凭证正确：aws sts get-caller-identity
# ═══════════════════════════════════════════════════════════════════════════════
import os
import re
import subprocess
import sys
import time

RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
CYAN = '\033[0;36m'
NC = '\033[0m'

success = 0
skip = 0
fail = 0

def _run(cmd, retries=5):
    for i in range(retries):
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
            err = (r.stderr + r.stdout).lower()
            if r.returncode == 0:
                return r
            if any(kw in err for kw in ['ssl', 'timeout', 'throttl', 'rate',
                    'connection', 'unavailable', 'bad gateway', 'internal']):
                if i < retries - 1: time.sleep((i+1)*2); continue
            return r
        except subprocess.TimeoutExpired:
            if i < retries - 1: time.sleep((i+1)*2); continue
            raise
    return None

def aws(*args):
    r = _run(['aws'] + list(args))
    return r.stdout.strip() if r and r.returncode == 0 else ''

def imp(addr, rid):
    global success, fail
    print(f'  导入: {addr}')
    r = _run(['terraform', 'import', addr, rid])
    if r and r.returncode == 0:
        print(f'  {GREEN}✓ 导入成功{NC}'); success += 1; return
    msg = (r.stderr + r.stdout) if r else ''
    if 'already' in msg.lower():
        print(f'  {GREEN}✓ 已导入（跳过）{NC}'); success += 1; return
    print(f'  {YELLOW}⚠ 导入失败{NC}'); fail += 1

def imp_opt(addr, rid):
    global skip
    if rid and rid != 'None': imp(addr, rid)
    else: print(f'  {YELLOW}⚠ 跳过 {addr}{NC}'); skip += 1

print('=' * 48)
print('  Smart Invest — AWS 资源导入脚本')
print('=' * 48 + '\n')

print(f'{CYAN}>>> 确认当前 AWS 身份...{NC}')
print(_run(['aws', 'sts', 'get-caller-identity']).stdout)
input('以上是你的目标 AWS 账号吗？按 Enter 继续 / Ctrl+C 取消 ')

# ═══ 读取配置 ═══
print(f'\n{CYAN}>>> 读取项目配置...{NC}')
pn, s3n, awsr = 'smart-invest', '', 'ap-southeast-1'
if os.path.exists('terraform.tfvars'):
    c = open('terraform.tfvars').read()
    if m := re.search(r'project_name\s*=\s*"(.*?)"', c): pn = m.group(1)
    if m := re.search(r's3_bucket_name\s*=\s*"(.*?)"', c): s3n = m.group(1)
    if m := re.search(r'aws_region\s*=\s*"(.*?)"', c): awsr = m.group(1)
print(f'  project_name: {pn}'); print(f'  aws_region:   {awsr}')
print(f'  s3_bucket:    {s3n or "（未配置）"}')
print()

# ═══ Phase 1: IAM ═══
print(f'{CYAN}━━━ [Phase 1/4] IAM 角色与权限 ━━━{NC}')
rn = f'{pn}-ec2-role'
if aws('iam', 'get-role', '--role-name', rn, '--query', 'Role.RoleName', '--output', 'text'):
    print(f'  {GREEN}✓ IAM 角色存在{NC}')
    imp(f'module.iam.aws_iam_role.ec2_role', rn)
    if aws('iam', 'get-instance-profile', '--instance-profile-name', rn, '--query', 'InstanceProfile.InstanceProfileName', '--output', 'text'):
        print(f'  {GREEN}✓ Instance Profile 存在{NC}')
        imp(f'module.iam.aws_iam_instance_profile.ec2_profile', rn)
    else: print(f'  {YELLOW}⚠ Instance Profile 不存在，跳过{NC}'); skip += 1
    # ✅ 修正：import 实际绑定的 3 个策略（SES / ECR / SecretsManager）
    #    原来的 CloudWatchAgentServerPolicy / AmazonSSMManagedInstanceCore 实际未绑定，已删除
    att = aws('iam', 'list-attached-role-policies', '--role-name', rn,
              '--query', 'AttachedPolicies[*].PolicyArn', '--output', 'text')

    for pol, label in [
        ('AmazonSESFullAccess',                    'ses'),
        ('AmazonEC2ContainerRegistryFullAccess',    'ecr'),
        ('SecretsManagerReadWrite',                 'secrets'),
    ]:
        if pol in att:
            imp(f'module.iam.aws_iam_role_policy_attachment.{label}',
                f'{rn}/arn:aws:iam::aws:policy/{pol}')
        else:
            print(f'  {YELLOW}⚠ {pol} 未绑定，跳过{NC}'); skip += 1
else: print(f'  {YELLOW}⚠ IAM 角色不存在，跳过{NC}'); skip += 1

# ═══ Phase 2: SG + EC2 + EIP ═══
print(f'\n{CYAN}━━━ [Phase 2/4] SG + EC2 + EIP ━━━{NC}')

sg = aws('ec2', 'describe-security-groups', '--region', awsr, '--filters', f'Name=group-name,Values={pn}-security-group', '--query', 'SecurityGroups[0].GroupId', '--output', 'text')
if not sg or sg == 'None': print(f'{RED}✗ 未找到安全组{NC}'); sys.exit(1)
print(f'{GREEN}✓ 安全组: {sg}{NC}'); imp(f'module.networking.aws_security_group.smart_invest', sg)

ec2 = ''
for tag in [f'{pn}-k3s-server', f'{pn}-server']:
    ec2 = aws('ec2', 'describe-instances', '--region', awsr, '--filters', f'Name=tag:Name,Values={tag}', 'Name=instance-state-name,Values=running,stopped', '--query', 'Reservations[*].Instances[*].InstanceId | [0][0]', '--output', 'text')
    if ec2 and ec2 != 'None': print(f'{GREEN}✓ EC2 (tag:Name={tag}): {ec2}{NC}'); break
if not ec2 or ec2 == 'None': print(f'{RED}✗ 未找到 EC2{NC}'); sys.exit(1)
imp(f'module.compute.aws_instance.k3s_server', ec2)

eip = aws('ec2', 'describe-addresses', '--region', awsr, '--filters', f'Name=instance-id,Values={ec2}', '--query', 'Addresses[0].AllocationId', '--output', 'text')
if not eip or eip == 'None': eip = aws('ec2', 'describe-addresses', '--region', awsr, '--query', "Addresses[?AssociationId==null].AllocationId | [0]", '--output', 'text')
if not eip or eip == 'None': print(f'{RED}✗ 未找到 EIP{NC}'); sys.exit(1)
print(f'{GREEN}✓ EIP: {eip} ({aws("ec2", "describe-addresses", "--region", awsr, "--allocation-ids", eip, "--query", "Addresses[0].PublicIp", "--output", "text")}){NC}')
imp(f'module.compute.aws_eip.k3s', eip)

# ═══ Phase 3: CDN ═══
print(f'\n{CYAN}━━━ [Phase 3/4] CDN (S3 + OAC + CloudFront) ━━━{NC}')
# ✅ 修正：WAF 已改为 data source，无需 import，直接跳过
print(f'  {CYAN}ℹ WAF 为 data source（由 CloudFront 自动创建），跳过 import{NC}')
skip += 1

bkt = aws('s3api', 'list-buckets', '--query', f"Buckets[?starts_with(Name, '{pn}')].Name | [0]", '--output', 'text')
if not bkt or bkt == 'None': print(f'{RED}✗ 未找到 S3{NC}'); sys.exit(1)
print(f'{GREEN}✓ S3: {bkt}{NC}'); imp(f'module.cdn.aws_s3_bucket.frontend', bkt)
imp_opt(f'module.cdn.aws_s3_bucket_public_access_block.frontend', bkt)
imp_opt(f'module.cdn.aws_s3_bucket_policy.frontend', bkt)

# ✅ 修正：S3 versioning 实际未开启，对应 resource 已从 .tf 删除，跳过 import
print(f'  {CYAN}ℹ S3 versioning 未开启，跳过 import{NC}')
skip += 1

oac = aws('cloudfront', 'list-origin-access-controls', '--query', "OriginAccessControlList.Items[0].Id", '--output', 'text')
if oac and oac != 'None': print(f'{GREEN}✓ OAC: {oac}{NC}'); imp_opt(f'module.cdn.aws_cloudfront_origin_access_control.s3_oac', oac)
else: print(f'{YELLOW}⚠ 无 OAC{NC}'); skip += 1

cf = aws('cloudfront', 'list-distributions', '--query', "DistributionList.Items[0].Id", '--output', 'text')
if not cf or cf == 'None': print(f'{RED}✗ 未找到 CloudFront{NC}'); sys.exit(1)
print(f'{GREEN}✓ CloudFront: {cf}{NC}'); imp(f'module.cdn.aws_cloudfront_distribution.main', cf)

# ═══ Done ═══
print(f'\n{"="*48}\n  导入结果汇总\n{"="*48}')
print(f'  {GREEN}成功: {success}{NC}\n  {YELLOW}跳过: {skip}{NC}\n  失败: {fail}')
print(f'\n{"="*48}\n  {GREEN}✅ 导入脚本执行完成！{NC}\n{"="*48}')
print('\n正在运行 terraform plan 验证...\n')
_r = _run(['terraform', 'plan'])
if _r and _r.returncode == 0: print(_r.stdout)
else: print(_r.stderr if _r else 'No output'); sys.exit(1 if _r else 0)
