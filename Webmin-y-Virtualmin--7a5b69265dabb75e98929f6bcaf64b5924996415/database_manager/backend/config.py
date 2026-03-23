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


APP_ENV = os.getenv("APP_ENV", os.getenv("FLASK_ENV", "development")).lower()
IS_PRODUCTION = APP_ENV == "production"

DEFAULT_SQLITE_PATH = os.path.join(BASE_DIR, "app.db")
DEFAULT_SECRET_KEY = os.getenv("APP_SECRET_KEY") or (
    None if IS_PRODUCTION else "local-development-secret-change-me"
)

if IS_PRODUCTION and not DEFAULT_SECRET_KEY:
    raise RuntimeError(
        "APP_SECRET_KEY es obligatorio cuando APP_ENV=production"
    )


class Config:
    ENV = APP_ENV
    DEBUG = _to_bool(os.getenv("APP_DEBUG"), default=not IS_PRODUCTION)
    TESTING = _to_bool(os.getenv("APP_TESTING"), default=False)

    SECRET_KEY = DEFAULT_SECRET_KEY
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY") or SECRET_KEY
    JWT_SALT = os.getenv("JWT_SALT", "database-manager-auth")
    AUTH_TOKEN_MAX_AGE = _to_int(os.getenv("AUTH_TOKEN_MAX_AGE"), 3600)

    SQLALCHEMY_DATABASE_URI = os.getenv(
        "DATABASE_URL",
        f"sqlite:///{DEFAULT_SQLITE_PATH}",
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    ALLOW_PUBLIC_REGISTRATION = _to_bool(
        os.getenv("ALLOW_PUBLIC_REGISTRATION"),
        default=False,
    )
    BOOTSTRAP_ADMIN_USERNAME = os.getenv("BOOTSTRAP_ADMIN_USERNAME", "")
    BOOTSTRAP_ADMIN_PASSWORD = os.getenv("BOOTSTRAP_ADMIN_PASSWORD", "")

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
CORS_ORIGINS = Config.CORS_ORIGINS
SUPPORTED_DATABASES = Config.SUPPORTED_DATABASES
DEFAULT_CONNECTION_PARAMS = Config.DEFAULT_CONNECTION_PARAMS
