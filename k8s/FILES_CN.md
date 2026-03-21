# Kubernetes 文件说明

这份文档用于简要说明 `k8s/` 目录下每个文件的作用，方便快速查阅。

## 顶层文件

- `README.md`
  Kubernetes 部署说明文档，主要介绍 Minikube 本地部署所需的前置条件、部署步骤、验证命令和清理方式。

- `FILES.md`
  英文版文件说明，用来快速查看每个 manifest 的职责。

- `FILES_CN.md`
  本文件。提供 `k8s/` 目录结构的中文说明。

## base/

`base/` 目录存放的是通用 Kubernetes 资源定义，描述了项目的核心服务。这些文件设计为可被不同环境复用。

- `base/kustomization.yaml`
  `base` 层的入口文件。它声明了需要加载的基础资源，并生成 PostgreSQL 和 backend 共同使用的 ConfigMap 与 Secret。

- `base/schema.sql`
  Kustomize 在生成数据库初始化 ConfigMap 时使用的本地 schema 副本。之所以放在 `k8s/base` 目录内，是为了避免 `kubectl apply -k` 因路径安全限制而报错。

- `base/namespace.yaml`
  创建 `transaction-platform` 命名空间，用于将项目资源统一放到一个独立 namespace 中。

- `base/postgres-pvc.yaml`
  为 PostgreSQL 定义持久化存储声明，保证数据库 Pod 重启后数据不会丢失。

- `base/postgres-deployment.yaml`
  定义 PostgreSQL Deployment。它负责启动数据库容器、注入数据库配置、挂载持久卷，并加载初始化 schema。

- `base/postgres-service.yaml`
  为 PostgreSQL 提供集群内部访问入口，使其他 Pod 可以通过固定服务名连接数据库。

- `base/backend-deployment.yaml`
  定义 Node.js reporting service 的 Deployment。它负责注入运行时环境变量，并为 `/health` 配置 readiness 和 liveness 探针。

- `base/backend-service.yaml`
  在集群内部暴露 backend 服务，端口为 `8080`。

- `base/network-policy.yaml`
  为 PostgreSQL 设置网络访问限制，只允许 backend Pod 通过 TCP `5432` 访问数据库。

## overlays/minikube/

`overlays/minikube/` 目录存放 Minikube 本地开发环境专用的覆盖配置。

- `overlays/minikube/kustomization.yaml`
  Minikube overlay 的入口文件。它引用共享的 `base/` 资源，并对本地环境做定制，例如把 backend 镜像标签替换为本地构建版本。

- `overlays/minikube/backend-service-patch.yaml`
  覆盖 backend Service 的类型，把 `ClusterIP` 改为 `NodePort`，这样本地开发时可以从集群外直接访问 backend。

## k8s 目录外但与部署相关的文件

- `database/schema.sql`
  项目数据库设计的源 schema 文件。后续如果 schema 有变更，需要和 `base/schema.sql` 保持一致。

- `backend/Dockerfile`
  backend 服务的容器镜像构建文件，Kubernetes 部署时使用该镜像运行应用。

- `docker-compose.yml`
  另一套本地容器编排方式。它不属于 Kubernetes 部署流程，但在用途上和本地 K8s 部署类似，适合 Docker Compose 场景。