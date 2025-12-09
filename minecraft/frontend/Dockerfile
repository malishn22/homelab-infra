FROM node:22-alpine AS builder
WORKDIR /app
COPY apps/minecraft/frontend/package*.json ./
RUN npm ci
COPY apps/minecraft/frontend .
ARG VITE_API_BASE_URL=""
RUN VITE_API_BASE_URL="$VITE_API_BASE_URL" npm run build

FROM nginx:1.27-alpine
COPY --from=builder /app/dist /usr/share/nginx/html
CMD ["sh", "-c", "set -e; : \"${MINECRAFT_API_PORT:=8000}\"; : \"${MINECRAFT_WEB_INTERNAL_PORT:=80}\"; cat > /etc/nginx/conf.d/default.conf <<EOF\nserver {\n    listen ${MINECRAFT_WEB_INTERNAL_PORT};\n    server_name _;\n    root /usr/share/nginx/html;\n    index index.html;\n\n    location /api/ {\n        proxy_pass http://minecraft-api:${MINECRAFT_API_PORT};\n        proxy_set_header Host \\$host;\n        proxy_set_header X-Real-IP \\$remote_addr;\n    }\n\n    location / {\n        try_files \\$uri \\$uri/ /index.html;\n    }\n}\nEOF\nexec nginx -g 'daemon off;'"]