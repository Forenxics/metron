# Multi-stage build for Metron Alerts UI
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY ../../metron-interface/metron-alerts/package*.json ./

# Install dependencies
RUN npm ci --legacy-peer-deps

# Copy source code
COPY ../../metron-interface/metron-alerts/ ./

# Build application
RUN npm run build -- --configuration production

# Production stage
FROM nginx:alpine

LABEL maintainer="Apache Metron Team"
LABEL description="Metron Alerts UI - Modern Angular Application"

# Copy built application
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Create non-root user
RUN addgroup -g 1001 metron && \
    adduser -D -u 1001 -G metron metron && \
    chown -R metron:metron /usr/share/nginx/html && \
    chown -R metron:metron /var/cache/nginx && \
    chown -R metron:metron /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown -R metron:metron /var/run/nginx.pid

USER metron

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=10s CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
