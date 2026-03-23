import os


BASE_DIR = os.path.abspath(os.path.dirname(__file__))


def _to_bool(value, default=False):
    if value is None:
        return default
    return str(value).strip().lower() in {"1", "true", "yes", "on"}


def _to_int(value, default):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _parse_origins(value):
    if not value:
        return []
    return [origin.strip() for origin in value.split(",") if origin.strip()]


def _get_required_env(name, allow_insecure_dev_default=None):
    value = os.getenv(name)
    if value:
        return value

    if allow_insecure_dev_default is None:
        raise RuntimeError(f"{name} es obligatorio")

    if IS_PRODUCTION:
        raise RuntimeError(f"{name} es obligatorio cuando APP_ENV=production")

    return allow_insecure_dev_default


APP_ENV = os.getenv("APP_ENV", os.getenv("FLASK_ENV", "development")).lower()
IS_PRODUCTION = APP_ENV == "production"

DEFAULT_SQLITE_PATH = os.path.join(BASE_DIR, "app.db")
APP_SECRET_KEY = _get_required_env(
    "APP_SECRET_KEY",
    allow_insecure_dev_default=None,
)
JWT_SECRET = _get_required_env(
    "JWT_SECRET_KEY",
    allow_insecure_dev_default=None,
)
JWT_SALT_VALUE = _get_required_env(
    "JWT_SALT",
    allow_insecure_dev_default=None,
)
DATABASE_URI = os.getenv("DATABASE_URL")

if IS_PRODUCTION and not DATABASE_URI:
    raise RuntimeError("DATABASE_URL es obligatorio cuando APP_ENV=production")

if not DATABASE_URI:
    DATABASE_URI = f"sqlite:///{DEFAULT_SQLITE_PATH}"


class Config:
    ENV = APP_ENV
    DEBUG = _to_bool(os.getenv("APP_DEBUG"), default=not IS_PRODUCTION)
    TESTING = _to_bool(os.getenv("APP_TESTING"), default=False)

    SECRET_KEY = APP_SECRET_KEY
    JWT_SECRET_KEY = JWT_SECRET
    JWT_SALT = JWT_SALT_VALUE
    AUTH_TOKEN_MAX_AGE = _to_int(os.getenv("AUTH_TOKEN_MAX_AGE"), 3600)
    LOGIN_RATE_LIMIT_ATTEMPTS = _to_int(os.getenv("LOGIN_RATE_LIMIT_ATTEMPTS"), 5)
    LOGIN_RATE_LIMIT_WINDOW_SECONDS = _to_int(
        os.getenv("LOGIN_RATE_LIMIT_WINDOW_SECONDS"),
        900,
    )
    LOGIN_LOCKOUT_SECONDS = _to_int(os.getenv("LOGIN_LOCKOUT_SECONDS"), 900)

    SQLALCHEMY_DATABASE_URI = DATABASE_URI
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    ALLOW_PUBLIC_REGISTRATION = _to_bool(
        os.getenv("ALLOW_PUBLIC_REGISTRATION"),
        default=False,
    )
    ENABLE_BOOTSTRAP_ADMIN = _to_bool(
        os.getenv("ENABLE_BOOTSTRAP_ADMIN"),
        default=not IS_PRODUCTION,
    )
    ALLOW_SQLITE_FILE_CONNECTIONS = _to_bool(
        os.getenv("ALLOW_SQLITE_FILE_CONNECTIONS"),
        default=not IS_PRODUCTION,
    )
    BOOTSTRAP_ADMIN_USERNAME = os.getenv("BOOTSTRAP_ADMIN_USERNAME", "")
    BOOTSTRAP_ADMIN_PASSWORD = os.getenv("BOOTSTRAP_ADMIN_PASSWORD", "")
    ALLOWED_DB_HOSTS = _parse_origins(
        os.getenv("ALLOWED_DB_HOSTS", "localhost,127.0.0.1")
    )

    CORS_ORIGINS = _parse_origins(
        os.getenv(
            "CORS_ALLOWED_ORIGINS",
            "http://localhost:3000,http://127.0.0.1:3000" if not IS_PRODUCTION else "",
        )
    )

    SUPPORTED_DATABASES = {
        "mysql": "MySQL",
        "postgresql": "PostgreSQL",
        "sqlite": "SQLite",
    }

    DEFAULT_CONNECTION_PARAMS = {
        "mysql": {
            "host": os.getenv("MYSQL_HOST", "localhost"),
            "port": _to_int(os.getenv("MYSQL_PORT"), 3306),
            "username": os.getenv("MYSQL_USERNAME", ""),
        },
        "postgresql": {
            "host": os.getenv("POSTGRES_HOST", "localhost"),
            "port": _to_int(os.getenv("POSTGRES_PORT"), 5432),
            "username": os.getenv("POSTGRES_USERNAME", ""),
        },
        "sqlite": {
            "database": os.getenv("SQLITE_DATABASE", DEFAULT_SQLITE_PATH),
        },
    }


SECRET_KEY = Config.SECRET_KEY
JWT_SECRET_KEY = Config.JWT_SECRET_KEY
JWT_SALT = Config.JWT_SALT
AUTH_TOKEN_MAX_AGE = Config.AUTH_TOKEN_MAX_AGE
SQLALCHEMY_DATABASE_URI = Config.SQLALCHEMY_DATABASE_URI
SQLALCHEMY_TRACK_MODIFICATIONS = Config.SQLALCHEMY_TRACK_MODIFICATIONS
ALLOW_PUBLIC_REGISTRATION = Config.ALLOW_PUBLIC_REGISTRATION
ENABLE_BOOTSTRAP_ADMIN = Config.ENABLE_BOOTSTRAP_ADMIN
ALLOW_SQLITE_FILE_CONNECTIONS = Config.ALLOW_SQLITE_FILE_CONNECTIONS
CORS_ORIGINS = Config.CORS_ORIGINS
ALLOWED_DB_HOSTS = Config.ALLOWED_DB_HOSTS
SUPPORTED_DATABASES = Config.SUPPORTED_DATABASES
DEFAULT_CONNECTION_PARAMS = Config.DEFAULT_CONNECTION_PARAMS
