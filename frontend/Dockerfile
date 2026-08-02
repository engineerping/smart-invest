# =============================================================================
# frontend Dockerfile —— 多阶段构建
# =============================================================================
# 阶段1: Node 构建 React 静态文件
# 阶段2: nginx 托管静态文件 + 反向代理 API 到网关
# =============================================================================
FROM node:22-alpine AS builder
WORKDIR /build
# 先拷贝依赖清单，利用层缓存
COPY package.json package-lock.json ./
RUN npm ci
# 拷贝源码并构建（VITE_API_BASE_URL 为空 = 同源，走 nginx 代理）
COPY . .
RUN npm run build

FROM nginx:1.27-alpine
# 覆盖默认 nginx 配置（用我们的反向代理配置）
COPY nginx.conf /etc/nginx/conf.d/default.conf
# 把构建产物拷进 nginx 的静态根目录
COPY --from=builder /build/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
