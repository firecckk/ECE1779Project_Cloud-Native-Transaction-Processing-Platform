# 🚀 新设备快速上手指南

## 项目概览

ECE1779 云原生交易处理平台是一个微服务架构的交易处理系统，包含数据摄入、验证、报告生成和前端等服务。

**核心特性**：
- ✅ 交易摄入与状态追踪（Event Sourcing）
- ✅ 风险评分与规则验证（HIGH_AMOUNT、DUPLICATE_PATTERN、FREQUENCY_ANOMALY）
- ✅ 报告与分析（日交易量、商户排名、风险分布）
- ✅ 多环境支持（本地 Docker Compose、Kubernetes Minikube、DigitalOcean）

---

## 📂 项目文件结构详解

```
ECE1779Project_Cloud-Native-Transaction-Processing-Platform/
│
├── shared/                          # ⭐️ 共享库（配置、数据库）
│   └── src/
│       ├── config.js                # 环境变量解析（PORT, DATABASE_URL, LOG_LEVEL）
│       └── db.js                    # PostgreSQL 连接池 + 查询工具函数
│
├── backend/                         # 后端微服务
│   ├── Dockerfile                   # Docker 镜像定义（从仓库根目录构建）
│   ├── package.json                 # npm 依赖（pg@8.13.1, express@4.21.2）
│   ├── src/
│   │   ├── server.js               # 启动入口（读取 shared/* 配置）
│   │   ├── app.js                  # Express 应用初始化
│   │   ├── service/
│   │   │   ├── ingestion/          # 📥 交易摄入服务
│   │   │   │   └── routes/
│   │   │   │       └── transactions.js   # POST /transactions（数据入库 + 审计）
│   │   │   │
│   │   │   ├── validation/         # ✔️ 风险验证服务 ⭐️ 核心规则引擎
│   │   │   │   ├── routes/
│   │   │   │   │   └── validation.js    # GET /health, POST /run-once
│   │   │   │   └── worker.js            # 📌 **规则评估逻辑（改这里修改验证规则）**
│   │   │   │
│   │   │   └── reporting/          # 📊 报告生成服务
│   │   │       └── routes/
│   │   │           └── reports.js   # GET /reports/{daily-volume|merchant-ranking|risk-distribution}
│   │   │
│   │   └── utils/                  # 工具函数（可选）
│
├── database/                        # 📊 数据库定义
│   ├── schema.sql                   # PostgreSQL Schema（transactions, transaction_status_audit 表）
│   └── readme.md
│
├── k8s/                             # Kubernetes 配置
│   ├── base/
│   │   ├── schema.sql              # （Schema 副本，用于 K8s ConfigMap）
│   │   ├── deployment.yaml         # Pod 定义
│   │   └── service.yaml            # Service 对外暴露
│   ├── overlays/
│   │   ├── minikube/               # 本地 Minikube 配置
│   │   └── doks/                   # DigitalOcean Kubernetes 配置
│   └── README.md                   # K8s 部署说明
│
├── scripts/                         # 🛠️ 实用脚本
│   ├── sync-schema.sh              # 同步 schema 到 K8s 基础配置（Linux/Mac）
│   ├── sync-schema.ps1             # 同步 schema 到 K8s 基础配置（Windows）
│   ├── transaction-generator.js    # 生成测试交易数据
│   └── README.md                   # 脚本使用说明
│
├── docker-compose.yml              # 本地开发编排文件
├── DOCKER_SETUP.md                 # Docker Compose 详细指南
├── .gitignore
├── README.md                        # 📋 主项目说明（你也在这里）
│
└── Proj_plan/                       # 📝 规划文档
    ├── proposalTeam27.md           # 初始提案
    ├── observability.md            # 可观测性设计
    ├── security.md                 # 安全规范
    ├── state-machine.md            # 交易状态机
    └── manual/                      # ⭐️ 团队运维手册
        └── QUICK_START.md          # （你在这里）
```

---

## 🔧 常见修改位置

### 🎯 修改验证规则（风险评分、阈值）
**位置**： [`backend/src/service/validation/worker.js`](../../backend/src/service/validation/worker.js)

**关键代码位置**：
- **L21-26**：规则常数定义
  ```javascript
  HIGH_AMOUNT_MEDIUM_THRESHOLD = 1000;
  HIGH_AMOUNT_CRITICAL_THRESHOLD = 5000;
  DUPLICATE_LOOKBACK_HOURS = 24;
  FREQUENCY_LOOKBACK_MINUTES = 10;
  FREQUENCY_ANOMALY_THRESHOLD = 5;
  RECIPIENT_CRITICAL_THRESHOLD = 10;
  REJECT_RISK_THRESHOLD = 70;
  ```

- **L29-110**：`evaluateRules(client, transaction)` ← **规则评估函数在这里，新增规则从这里开始**
- **L112-130**：`applyValidationDecision(client, transaction, decision)` ← 决策应用（状态转移、审计日志）

**示例：添加新规则**
```javascript
// 在 evaluateRules() 中添加新的 if 块
if (/* 你的条件 */) {
    reasons.push("YOUR_NEW_RULE");
    riskScore += 50;  // 加分
}
```

### 🌍 修改环境变量与配置
**位置**： [`shared/src/config.js`](../../shared/src/config.js)

**当前支持的环境变量**：
- `PORT` - API 监听端口（默认 8080）
- `DATABASE_URL` - PostgreSQL 连接字符串（默认 `postgres://transaction_user:password@localhost:5432/transaction_platform`）
- `LOG_LEVEL` - 日志级别（默认 `info`）

**修改方法**：
```bash
# 方式1：启动前设置环境变量
export PORT=9000
export LOG_LEVEL=debug
docker-compose up

# 方式2：在 docker-compose.yml 中修改 environment 块
# 方式3：改 docker-compose.yml 的 .env 文件
```

### 📥 修改交易摄入逻辑
**位置**： [`backend/src/service/ingestion/routes/transactions.js`](../../backend/src/service/ingestion/routes/transactions.js)

**关键函数**：
- `validateTransactionPayload()` - 请求字段校验（uuid、idempotency_key、amount）
- `insertTransaction()` - 事务插入（transactions 表 + audit 记录）

**常见修改**：
- 添加新的字段验证：在 `validateTransactionPayload()` 中添加检查
- 修改入库流程：在 `client.query()` 中调整 INSERT 字段或值

### 📊 修改报告查询逻辑
**位置**： [`backend/src/service/reporting/routes/reports.js`](../../backend/src/service/reporting/routes/reports.js)

**三个报告端点**：
1. `GET /reports/daily-volume` - 日交易量聚合（L15-40）
2. `GET /reports/merchant-ranking` - 商户排名（L42-70）
3. `GET /reports/risk-distribution` - 风险分布（L72-100）

**修改方法**：编辑对应的 SQL 查询或响应格式

### 🗄️ 修改数据库 Schema
**位置**： [`database/schema.sql`](../../database/schema.sql)

⚠️ **重要**：修改后需要同步到 K8s 配置
```bash
# Linux/Mac
./scripts/sync-schema.sh

# Windows PowerShell
.\scripts\sync-schema.ps1
```

---

## 🚀 快速启动（5 分钟）

### 前置要求
- ✅ Docker Desktop（或 Docker + Docker Compose）
- ✅ PowerShell 或 Bash（运行脚本）
- ✅ Git（克隆项目）

### 步骤 1️⃣：启动服务
```bash
# 进入项目目录
cd ECE1779Project_Cloud-Native-Transaction-Processing-Platform

# 启动所有容器（包括 PostgreSQL）
docker-compose up -d --build

# 查看容器状态
docker-compose ps
```

**预期输出**：
```
NAME              STATUS
backend           Up 2 seconds
postgres          Up 5 seconds
```

### 步骤 2️⃣：验证健康状态
```bash
# 检查后端健康
curl http://localhost:8080/health

# 预期响应
{"status":"ok"}
```

### 步骤 3️⃣：测试交易摄入
```bash
# 插入一笔交易（PowerShell）
$body = @{
    transaction_id = "11111111-0000-1000-a000-000000000002"
    idempotency_key = "test-key-002"
    event_timestamp = Get-Date -AsUTC -Format "yyyy-MM-ddTHH:mm:ssZ"
    sender_account = "acc-bob"
    receiver_account = "acc-jerry"
    merchant_id = "merchant-002"
    amount = 1500.25
    currency = "USD"
    transaction_type = "PAYMENT"
    channel = "WEB"
    metadata = @{ source = "quickstart" }
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8080/transactions" `
    -Method POST `
    -ContentType "application/json" `
    -Body $body | ConvertTo-Json

# Bash 脚本版本
curl -X POST http://localhost:8080/transactions \
  -H "Content-Type: application/json" \
  -d '{
        "transaction_id": "00000001-0000-1000-a000-000000000001",
    "idempotency_key": "test-key-001",
        "event_timestamp": "'$(date -u +'%Y-%m-%dT%H:%M:%SZ')'",
        "sender_account": "acc-alice",
        "receiver_account": "acc-bob",
    "merchant_id": "merchant-001",
    "amount": 1500.25,
    "currency": "USD",
        "transaction_type": "PAYMENT",
        "channel": "WEB",
        "metadata": {"source": "quickstart"}
    }'
```

### 步骤 4️⃣：运行验证规则
```bash
# 说明：当前后端在交易写入 RECEIVED 后会自动触发验证。
# 以下命令主要用于手动补跑/批量补偿。

# 触发验证处理
curl -X POST http://localhost:8080/validation/run-once -H "Content-Type: application/json" -d '{"limit": 20}'

# 预期响应：交易状态更新为 VALID 或 REJECTED
{"claimed_count": 1, "processed_count": 1, "valid_count": 1, "rejected_count": 0, ...}
```

### 步骤 5️⃣：查询报告
```bash
# 日交易量
curl "http://localhost:8080/reports/daily-volume?from=2026-03-01&to=2026-03-22"

# 商户排名（Top 5）
curl "http://localhost:8080/reports/merchant-ranking?from=2026-03-01&to=2026-03-22&limit=5"

# 风险分布（按 10 点分段）
curl "http://localhost:8080/reports/risk-distribution?from=2026-03-01&to=2026-03-22&bucket_size=10"
```

---

## 🗄️ 手动数据库查询

### 连接 PostgreSQL
```bash
# 在线进入 psql
docker-compose exec postgres psql -U transaction_user -d transaction_platform

# 或者本地 psql（如果已安装）
psql -h localhost -U transaction_user -d transaction_platform
# 密码: password
```

### 常用查询
```sql
-- 查看所有交易
SELECT transaction_id, sender_account, receiver_account, amount, status, risk_score, created_at 
FROM transactions LIMIT 10;

-- 查看审计日志（状态变更历史）
SELECT transaction_id, old_status, new_status, changed_at, changed_by 
FROM transaction_status_audit ORDER BY changed_at DESC LIMIT 10;

-- 按状态统计
SELECT status, COUNT(*) FROM transactions GROUP BY status;

-- 查看高风险交易（风险分数 >= 60）
SELECT transaction_id, sender_account, receiver_account, amount, risk_score, status 
FROM transactions WHERE risk_score >= 60 ORDER BY risk_score DESC;

-- 插入测试数据（不通过 API）
INSERT INTO transactions (
    transaction_id, idempotency_key, event_timestamp, sender_account, receiver_account,
    merchant_id, amount, currency, transaction_type, channel, status, risk_score, metadata
) VALUES (
    '00000002-0000-0000-0000-000000000002', 
    'manual-key-001',
    NOW(),
    'acc-charlie',
    'acc-diana',
    'merchant-002',
    2500.00,
    'USD',
    'PAYMENT',
    'WEB',
    'RECEIVED',
    0,
    '{}'::jsonb
);
```

---

## 🔍 常见调试命令

### 查看 Docker 日志
```bash
# 后端服务日志
docker-compose logs -f backend

# PostgreSQL 日志
docker-compose logs -f postgres

# 所有日志（跟随）
docker-compose logs -f
```

### 停止与清理
```bash
# 停止所有容器（保留数据）
docker-compose stop

# 停止并删除容器和卷（清空数据库）
docker-compose down -v

# 重启单个服务
docker-compose restart backend
```

### 执行一次性命令
```bash
# 在运行中的容器内执行命令
docker-compose exec backend npm list pg

# 查看环境变量
docker-compose exec backend printenv | grep -E "PORT|DATABASE"
```

---

## 🛠️ 开发工作流

### 场景 1：修改验证规则并测试
```bash
# 1. 编辑 backend/src/service/validation/worker.js
# 2. 重启后端容器以应用更改
docker-compose restart backend

# 3. 插入测试交易
# (使用上面的 curl 命令)

# 4. 运行验证
curl -X POST http://localhost:8080/validation/run-once -H "Content-Type: application/json" -d '{"limit": 20}'

# 5. 查看审计日志验证结果
docker-compose exec postgres psql -U transaction_user -d transaction_platform -c \
  "SELECT * FROM transaction_status_audit ORDER BY changed_at DESC LIMIT 5;"
```

### 场景 2：修改数据库 Schema
```bash
# 1. 编辑 database/schema.sql
# 2. 备份现有数据（可选）
docker-compose pause postgres

# 3. 使用 fresh 标志重启（这会删除旧数据）
docker-compose down -v
docker-compose up -d --build

# 4. 验证新 Schema
docker-compose exec postgres psql -U transaction_user -d transaction_platform -c "\dt"
```

### 场景 3：部署到 Kubernetes
```bash
# 1. 同步 Schema 到 K8s 配置
./scripts/sync-schema.sh   # 或 .\scripts\sync-schema.ps1 (Windows)

# 2. 应用 Minikube 配置
kubectl apply -k k8s/overlays/minikube

# 3. 验证部署
kubectl get pods
kubectl get svc

# 4. 端口转发并测试
kubectl port-forward svc/backend-service 8080:8080
curl http://localhost:8080/health
```

---

## 📚 更多资源

| 文档 | 用途 |
|------|------|
| [DOCKER_SETUP.md](../../DOCKER_SETUP.md) | Docker Compose 完整指南（包含备份、恢复、日志等） |
| [backend/README.md](../../backend/README.md) | API 端点详细说明与 curl 示例 |
| [k8s/README.md](../../k8s/README.md) | Kubernetes 部署与配置 |
| [scripts/README.md](../../scripts/README.md) | 工具脚本使用说明 |
| [Proj_plan/state-machine.md](../state-machine.md) | 交易状态机设计 |
| [Proj_plan/security.md](../security.md) | 安全规范与认证 |

---

## ❓ 常见问题

**Q: 修改代码后需要重新构建 Docker 镜像吗？**  
A: 是的。使用 `docker-compose up -d --build` 或 `docker-compose restart backend` 来应用更改。

**Q: 如何更改数据库密码？**  
A: 编辑 `docker-compose.yml` 的 `POSTGRES_PASSWORD` 和 `backend` 服务的 `DATABASE_URL`，然后 `docker-compose down -v && docker-compose up -d --build`。

**Q: validation/run-once 端点对交易数量有限制吗？**  
A: 默认一次处理 20 笔（可通过 `"limit"` 参数调整）。数据库使用 `FOR UPDATE SKIP LOCKED` 确保并发安全。

**Q: 如何查看哪些交易被 REJECTED 及原因？**  
A: 

```sql
SELECT transaction_id, status, risk_score, reject_reason FROM transactions 
WHERE status = 'REJECTED' ORDER BY created_at DESC;
```

**Q: 能在同一个 docker-compose 中跑多个后端实例吗？**  
A: 可以。编辑 `docker-compose.yml`，添加 `backend-2: << *backend` 并设置不同的 `ports` 和 `CONTAINER_NAME`。

---

## 🎓 架构思想

本项目采用 **共享库模式（Shared Library Pattern）** 实现微服务间的配置与数据库复用，**无冗余包装器**：

```
┌─────────────────────────────────────────┐
│       shared/src/                       │
│  ┌──────────────┐  ┌────────────────┐  │
│  │  config.js   │  │     db.js      │  │
│  │ (环境变量)   │  │ (数据库连接)   │  │
│  └──────────────┘  └────────────────┘  │
└─────────────────────────────────────────┘
   ▲                 ▲                 ▲
   │                 │                 │
┌──────┐        ┌──────────┐     ┌──────────┐
│      │        │          │     │          │
│摄入  │ Ingestion│  验证  │ Validation│报告 │Reporting│
│服务  │        │服务      │     │服务      │
└──────┘        └──────────┘     └──────────┘
```

所有服务通过 `require("../../../shared/src/config")` 和 `require("../../../shared/src/db")` 访问共享资源，确保配置和数据库连接的一致性。

---

**最后更新**：2026-03-22（移除冗余包装器文件）  
**维护者**：Team 27  
**问题反馈**：请在项目 Issues 中提出  

