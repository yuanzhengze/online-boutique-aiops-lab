# Review Service API 文档

## 服务概述

Review Service 是为 Online Boutique 新增的商品评价微服务，支持用户查询商品评价、提交评价和查看评分统计。服务使用 Python 标准库实现，无需额外依赖，通过 Docker 容器化部署到 Kubernetes 集群。

- **服务名称**：review-service
- **版本**：0.1.0
- **默认端口**：8080（通过环境变量 `PORT` 配置）
- **数据格式**：JSON
- **字符编码**：UTF-8
- **CORS**：已启用，允许所有来源访问

## 基础信息

| 项目 | 值 |
|------|-----|
| 服务地址（集群内） | `http://review-service:8080` |
| 服务地址（NodePort） | `http://<node-ip>:32180` |
| 健康检查 | `GET /healthz` |
| Prometheus 指标 | `GET /metrics` |

## 数据模型

### Review（评价）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | string | 评价唯一标识，自动生成 UUID |
| product_id | string | 商品 ID，对应 Online Boutique 中的商品 |
| user_name | string | 用户名，默认 "anonymous" |
| rating | integer | 评分，1-5 的整数 |
| content | string | 评价内容 |
| created_at | string | 创建时间，ISO 8601 格式（UTC） |

## 接口列表

### 1. 健康检查

检查服务是否正常运行。

```
GET /healthz
```

**响应示例**：

```json
{
  "status": "ok",
  "service": "review-service"
}
```

**状态码**：200

---

### 2. 查询评价

查询指定商品的评价列表。如果不传 product_id，返回所有评价。

```
GET /reviews?product_id={product_id}
```

**查询参数**：

| 参数 | 必填 | 说明 |
|------|------|------|
| product_id | 否 | 商品 ID，不传则返回所有评价 |

**响应示例**：

```json
{
  "reviews": [
    {
      "id": "seed-1",
      "product_id": "OLJCESPC7Z",
      "user_name": "alice",
      "rating": 5,
      "content": "Great product for demo checkout flows.",
      "created_at": "2026-06-03T00:00:00Z"
    },
    {
      "id": "seed-2",
      "product_id": "OLJCESPC7Z",
      "user_name": "bob",
      "rating": 4,
      "content": "Looks good in the Online Boutique demo.",
      "created_at": "2026-06-03T00:05:00Z"
    }
  ],
  "count": 2
}
```

**状态码**：200

---

### 3. 评分统计

查询指定商品的评分统计信息，包括平均分和各星级分布。

```
GET /reviews/summary?product_id={product_id}
```

**查询参数**：

| 参数 | 必填 | 说明 |
|------|------|------|
| product_id | 否 | 商品 ID，不传则统计所有评价 |

**响应示例**：

```json
{
  "product_id": "OLJCESPC7Z",
  "review_count": 2,
  "average_rating": 4.5,
  "rating_distribution": {
    "1": 0,
    "2": 0,
    "3": 0,
    "4": 1,
    "5": 1
  }
}
```

**状态码**：200

---

### 4. 提交评价

提交一条新的商品评价。

```
POST /reviews
```

**请求头**：

| 头部 | 值 |
|------|-----|
| Content-Type | application/json |

**请求体**：

| 字段 | 必填 | 类型 | 说明 |
|------|------|------|------|
| product_id | 是 | string | 商品 ID |
| content | 是 | string | 评价内容 |
| rating | 是 | integer | 评分，1-5 的整数 |
| user_name | 否 | string | 用户名，默认 "anonymous" |

**请求示例**：

```json
{
  "product_id": "OLJCESPC7Z",
  "user_name": "charlie",
  "rating": 5,
  "content": "Excellent quality, fast shipping!"
}
```

**成功响应示例**：

```json
{
  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "product_id": "OLJCESPC7Z",
  "user_name": "charlie",
  "rating": 5,
  "content": "Excellent quality, fast shipping!",
  "created_at": "2026-06-05T10:30:00Z"
}
```

**错误响应示例**：

```json
{
  "error": "product_id is required"
}
```

**状态码**：

| 状态码 | 说明 |
|--------|------|
| 201 | 评价创建成功 |
| 400 | 请求参数错误（缺少必填字段、rating 不在 1-5 范围、JSON 格式错误） |

**验证规则**：

- `product_id`：必填，不能为空
- `content`：必填，不能为空
- `rating`：必填，必须是 1-5 的整数
- `user_name`：选填，为空时默认为 "anonymous"

---

### 5. Prometheus 指标

暴露 Prometheus 格式的监控指标。

```
GET /metrics
```

**响应示例**：

```
# HELP review_service_reviews_total Total number of reviews.
# TYPE review_service_reviews_total gauge
review_service_reviews_total 2
# HELP review_service_average_rating Average rating by product.
# TYPE review_service_average_rating gauge
review_service_average_rating{product_id="OLJCESPC7Z"} 4.5
```

**状态码**：200

**指标说明**：

| 指标 | 类型 | 说明 |
|------|------|------|
| review_service_reviews_total | gauge | 评价总数 |
| review_service_average_rating | gauge | 按商品分组的平均评分 |

---

### 6. CORS 预检请求

浏览器跨域请求的预检处理。

```
OPTIONS /reviews
```

**响应**：204 No Content，包含 CORS 允许头。

## 部署说明

### Docker 构建

```bash
docker build -t review-service:0.1.0 .
```

### Kubernetes 部署

```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

### 验证部署

```bash
# 检查 Pod 状态
kubectl get pods -l app=review-service

# 健康检查
curl http://localhost:32180/healthz

# 查询评价
curl http://localhost:32180/reviews?product_id=OLJCESPC7Z
```

## 内置种子数据

服务启动时自带 2 条种子评价，商品 ID 为 `OLJCESPC7Z`（Online Boutique 默认商品），便于演示和测试。

## 前端集成

Review Service 已集成到 Online Boutique 商品详情页，评价区域包含：

- **评分统计**：平均评分（保留1位小数）+ 星级分布条形图
- **评价筛选**：全部/好评(4-5星)/中评(3星)/差评(1-2星) 标签切换
- **情感标签**：每条评价显示 positive/neutral/negative 标签
- **提交评价表单**：用户名、评分、评价内容
- **优雅降级**：Review Service 不可用时显示提示，不影响商品页面其他功能

集成方式：通过 Kubernetes ConfigMap 挂载修改后的 `product.html` 模板和 `review.css` 样式到 frontend Pod，无需重新编译 Go 二进制。JavaScript 在浏览器端通过 fetch 调用 Review Service API。

## 技术实现

- **语言**：Python 3.12
- **HTTP 服务**：标准库 `http.server.ThreadingHTTPServer`，支持并发请求
- **数据存储**：内存列表，线程安全（`threading.Lock`）
- **监控集成**：通过 Pod 注解 `prometheus.io/scrape=true` 自动被 Prometheus 发现和采集
