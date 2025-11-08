# Dockerfile for Streamlit Threat Hunting App
FROM python:3.11-slim

LABEL maintainer="Apache Metron Team"
LABEL description="Metron Streamlit Threat Hunting Application"

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .
COPY utils/ ./utils/

# Create non-root user
RUN useradd -m -u 1001 metron && \
    chown -R metron:metron /app

USER metron

EXPOSE 8501

HEALTHCHECK --interval=30s --timeout=10s CMD curl -f http://localhost:8501/_stcore/health || exit 1

CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]
