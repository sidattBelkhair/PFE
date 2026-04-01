import os
from pathlib import Path
from decouple import config

BASE_DIR = Path(__file__).resolve().parent.parent

# Créer le répertoire logs s'il n'existe pas
os.makedirs(BASE_DIR / 'logs', exist_ok=True)

SECRET_KEY = config('SECRET_KEY', default='your-secret-key-here')
DEBUG = config('DEBUG', default=True, cast=bool)
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='localhost,127.0.0.1,10.0.2.2', cast=lambda v: [s.strip() for s in v.split(',')])

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',

    # Third party
    'rest_framework',
    'corsheaders',
    'drf_spectacular',
    'django_filters',

    # Local
    'apps.core',
]

AUTH_USER_MODEL = 'core.User'

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    # SOC — doit être en dernier pour avoir accès à request.user
    'apps.core.security_middleware.SecurityMiddleware',
]

ROOT_URLCONF = 'fintech_bank.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'fintech_bank.wsgi.application'

# ─────────────────────────────────────────────
#  DATABASE — changer DB_ENGINE dans .env
#  SQLite  : DB_ENGINE=django.db.backends.sqlite3
#  MySQL   : DB_ENGINE=django.db.backends.mysql
#  Postgres: DB_ENGINE=django.db.backends.postgresql
# ─────────────────────────────────────────────
DB_ENGINE = config('DB_ENGINE', default='django.db.backends.sqlite3')

if DB_ENGINE == 'django.db.backends.sqlite3':
    DATABASES = {
        'default': {
            'ENGINE': DB_ENGINE,
            'NAME': BASE_DIR / 'db.sqlite3',
        }
    }
else:
    DATABASES = {
        'default': {
            'ENGINE': DB_ENGINE,
            'NAME': config('DB_NAME', default='fintech_db'),
            'USER': config('DB_USER', default='postgres'),
            'PASSWORD': config('DB_PASSWORD', default='password'),
            'HOST': config('DB_HOST', default='localhost'),
            'PORT': config('DB_PORT', default='5432'),
        }
    }

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'fr-fr'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticated',
    ),
    'DEFAULT_FILTER_BACKENDS': (
        'django_filters.rest_framework.DjangoFilterBackend',
        'rest_framework.filters.SearchFilter',
        'rest_framework.filters.OrderingFilter',
    ),
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
    'DEFAULT_SCHEMA_CLASS': 'drf_spectacular.openapi.AutoSchema',
}

# CORS — autoriser toutes les origines en DEBUG (développement)
if DEBUG:
    CORS_ALLOW_ALL_ORIGINS = True
else:
    CORS_ALLOWED_ORIGINS = [
        'http://localhost:3000',
        'http://localhost:5000',
        'http://localhost:8000',
        'http://127.0.0.1:5000',
        'http://127.0.0.1:8000',
        'http://10.0.2.2:8000',  # Émulateur Android
    ]

CORS_ALLOW_CREDENTIALS = True

from datetime import timedelta
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=60),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=1),
    'ALGORITHM': 'HS256',
    'SIGNING_KEY': SECRET_KEY,
    'USER_ID_FIELD': 'id',
    'USER_ID_CLAIM': 'user_id',
}

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {message}',
            'style': '{',
        },
        # Format brut pour les logs JSON (security + access) — pas de préfixe
        'raw': {
            'format': '%(message)s',
        },
    },
    'handlers': {
        'console': {
            'level': 'DEBUG',
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
        },
        # django.log — log général de l'application
        'django_file': {
            'level': 'INFO',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': BASE_DIR / 'logs' / 'django.log',
            'maxBytes': 10 * 1024 * 1024,  # 10 MB
            'backupCount': 5,
            'formatter': 'verbose',
        },
        # security.log — événements de sécurité (JSON pur pour Promtail)
        'security_file': {
            'level': 'WARNING',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': BASE_DIR / 'logs' / 'security.log',
            'maxBytes': 10 * 1024 * 1024,
            'backupCount': 10,
            'formatter': 'raw',
        },
        # access.log — toutes les requêtes HTTP (JSON pur pour Promtail)
        'access_file': {
            'level': 'INFO',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': BASE_DIR / 'logs' / 'access.log',
            'maxBytes': 20 * 1024 * 1024,
            'backupCount': 5,
            'formatter': 'raw',
        },
    },
    'loggers': {
        # Logger général Django
        'django': {
            'handlers': ['console', 'django_file'],
            'level': 'INFO',
            'propagate': False,
        },
        # Requêtes HTTP de Django
        'django.request': {
            'handlers': ['console', 'django_file'],
            'level': 'WARNING',
            'propagate': False,
        },
        # Événements de sécurité SOC
        'security': {
            'handlers': ['security_file', 'console'],
            'level': 'WARNING',
            'propagate': False,
        },
        # Access log SOC
        'access': {
            'handlers': ['access_file'],
            'level': 'INFO',
            'propagate': False,
        },
    },
    'root': {
        'handlers': ['console', 'django_file'],
        'level': 'INFO',
    },
}

# ── Email ───────────────────────────────────────────────────────────────────
# En DEBUG sans vraies credentials Gmail → console (OTP visible dans le terminal)
_email_user = config('EMAIL_HOST_USER', default='')
_email_pass = config('EMAIL_HOST_PASSWORD', default='')
_has_real_creds = bool(_email_user and _email_user != 'TON_EMAIL@gmail.com' and _email_pass and _email_pass != 'TON_MOT_DE_PASSE_APPLICATION')

if _has_real_creds:
    EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
    EMAIL_HOST = config('EMAIL_HOST', default='smtp.gmail.com')
    EMAIL_PORT = config('EMAIL_PORT', default=587, cast=int)
    EMAIL_USE_TLS = True
    EMAIL_HOST_USER = _email_user
    EMAIL_HOST_PASSWORD = _email_pass
    DEFAULT_FROM_EMAIL = _email_user
else:
    EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'
    EMAIL_HOST_USER = ''
    EMAIL_HOST_PASSWORD = ''
    DEFAULT_FROM_EMAIL = 'noreply@rssbank.mr'

# Cache pour le comptage brute-force (en mémoire)
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
        'LOCATION': 'rss-security-cache',
    }
}

# ── Loki (SOC distant) ──────────────────────────────────────────────────────
# Si LOKI_URL est défini dans .env, les logs de sécurité sont pushés vers Loki
LOKI_URL = config('LOKI_URL', default='')
if LOKI_URL:
    import logging_loki
    logging_loki.emitter.LokiEmitter.level_tag = 'level'
    LOGGING['handlers']['loki'] = {
        'class': 'logging_loki.LokiHandler',
        'url': f'{LOKI_URL}/loki/api/v1/push',
        'tags': {'app': 'sedad-bank', 'env': 'production'},
        'version': '1',
        'level': 'INFO',
    }
    for logger in LOGGING.get('loggers', {}).values():
        if 'handlers' in logger:
            logger['handlers'].append('loki')
