# 微服务源码目录

本目录用于存放新增微服务源码。

## 当前服务

### review-service/：商品评价服务

- **功能**：支持评价查询、评价提交和评分统计
- **技术栈**：Python 3.12 标准库（ThreadingHTTPServer），零外部依赖
- **API 端点**：5 个（/healthz、/reviews、/reviews/summary、POST /reviews、/metrics）
- **部署方式**：Docker 容器化 + K8s Deployment（NodePort 32180）
- **前端集成**：商品详情页底部展示评价区域（通过 ConfigMap 挂载模板）
- **监控**：Prometheus 自动采集（Pod 注解 + /metrics 端点）
- **详细文档**：[services/review-service/README.md](review-service/README.md)

## 提交要求

- 服务源码、依赖说明、运行命令放在对应服务目录下。
- 每个服务需要包含 README 或 API 文档。
- Dockerfile 放在服务目录或 `k8s/review-service/` 中，并在文档中说明。

