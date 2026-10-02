# syntax=docker/dockerfile:1
# Quartz v5 requires Node.js 22+.
FROM node:22-bookworm-slim AS dependencies
WORKDIR /app
COPY package.json package-lock.json .npmrc ./
COPY quartz/ ./quartz/
RUN npm ci && npx quartz plugin install

FROM dependencies AS build
COPY . .
RUN npx quartz build

# Runtime contains only generated static files and nginx.
FROM nginxinc/nginx-unprivileged:1.29-alpine AS runtime
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/public /usr/share/nginx/html
EXPOSE 8080
