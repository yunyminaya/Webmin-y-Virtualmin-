SECRET_KEY = 'your_secret_key_here'

# Supported databases
SUPPORTED_DATABASES = {
    'mysql': 'MySQL',
    'postgresql': 'PostgreSQL',
    'sqlite': 'SQLite'
}

# Default connection parameters
DEFAULT_CONNECTION_PARAMS = {
    'mysql': {
        'host': 'localhost',
        'port': 3306,
        'username': 'root',
        'password': ''
    },
    'postgresql': {
        'host': 'localhost',
        'port': 5432,
        'username': 'postgres',
        'password': ''
    },
    'sqlite': {
        'database': '/path/to/database.db'
    }
}
