# Dockerfile for Metron REST API
FROM eclipse-temurin:17-jre-alpine

LABEL maintainer="Apache Metron Team"
LABEL description="Metron REST API - Modern Spring Boot 3.x"

# Install dependencies
RUN apk add --no-cache curl bash

# Create app directory
WORKDIR /app

# Copy JAR file (built by Maven)
COPY ../../metron-interface/metron-rest/target/metron-rest-*.jar /app/metron-rest.jar

# Create non-root user
RUN addgroup -g 1001 metron && \
    adduser -D -u 1001 -G metron metron && \
    chown -R metron:metron /app

USER metron

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# JVM options
ENV JAVA_OPTS="-Xmx2g -Xms2g -XX:+UseG1GC -XX:MaxGCPauseMillis=200"

# Run application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/metron-rest.jar"]
