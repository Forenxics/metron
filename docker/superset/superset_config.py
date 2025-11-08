# Superset configuration for Metron

import os

# Flask App Builder configuration
ROW_LIMIT = 10000

# Flask-WTF flag for CSRF
WTF_CSRF_ENABLED = True

# Set this API key to enable Mapbox visualizations
MAPBOX_API_KEY = os.getenv('MAPBOX_API_KEY', '')

# Security
SECRET_KEY = os.getenv('SUPERSET_SECRET_KEY', 'metron-superset-secret-key-change-in-production')

# Database configuration
SQLALCHEMY_DATABASE_URI = f"postgresql://{os.getenv('DATABASE_USER')}:{os.getenv('DATABASE_PASSWORD')}@{os.getenv('DATABASE_HOST')}/{os.getenv('DATABASE_DB')}"

# Redis for caching and celery
REDIS_HOST = os.getenv('REDIS_HOST', 'superset-redis')
REDIS_PORT = os.getenv('REDIS_PORT', 6379)

# Cache configuration
CACHE_CONFIG = {
    'CACHE_TYPE': 'RedisCache',
    'CACHE_DEFAULT_TIMEOUT': 300,
    'CACHE_KEY_PREFIX': 'superset_',
    'CACHE_REDIS_HOST': REDIS_HOST,
    'CACHE_REDIS_PORT': REDIS_PORT,
}

# Celery configuration
class CeleryConfig:
    BROKER_URL = f'redis://{REDIS_HOST}:{REDIS_PORT}/0'
    CELERY_IMPORTS = ('superset.sql_lab',)
    CELERY_RESULT_BACKEND = f'redis://{REDIS_HOST}:{REDIS_PORT}/1'
    CELERY_ANNOTATIONS = {'tasks.add': {'rate_limit': '10/s'}}

CELERY_CONFIG = CeleryConfig

# Feature flags
FEATURE_FLAGS = {
    'ENABLE_TEMPLATE_PROCESSING': True,
    'DASHBOARD_NATIVE_FILTERS': True,
    'DASHBOARD_CROSS_FILTERS': True,
    'DASHBOARD_RBAC': True,
}

# Elasticsearch configuration for Metron
ELASTICSEARCH_HOSTS = [os.getenv('ELASTICSEARCH_URL', 'http://elasticsearch:9200')]
