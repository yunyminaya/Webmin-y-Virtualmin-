import logging
import re

from sqlalchemy import inspect, text
from sqlalchemy.engine import URL, create_engine


logger = logging.getLogger(__name__)

class DatabaseService:
    IDENTIFIER_PATTERN = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*$')

    def __init__(self, db_type, connection_params, allowed_hosts=None):
        self.db_type = db_type
        self.connection_params = connection_params
        self.allowed_hosts = {host.strip() for host in (allowed_hosts or []) if host.strip()}
        self.engine = self._create_engine()

    def _validate_host(self):
        if self.db_type not in {'mysql', 'postgresql'}:
            return

        host = (self.connection_params.get('host') or '').strip()
        if not host:
            raise ValueError('El host de base de datos es obligatorio')

        if self.allowed_hosts and host not in self.allowed_hosts:
            raise ValueError('El host solicitado no está permitido')
        
    def _create_engine(self):
        self._validate_host()

        if self.db_type == 'mysql':
            conn_string = URL.create(
                drivername='mysql+pymysql',
                username=self.connection_params.get('username'),
                password=self.connection_params.get('password'),
                host=self.connection_params.get('host', 'localhost'),
                port=int(self.connection_params.get('port', 3306)),
                database=self.connection_params.get('database') or None,
            )
        elif self.db_type == 'postgresql':
            conn_string = URL.create(
                drivername='postgresql+psycopg2',
                username=self.connection_params.get('username'),
                password=self.connection_params.get('password'),
                host=self.connection_params.get('host', 'localhost'),
                port=int(self.connection_params.get('port', 5432)),
                database=self.connection_params.get('database', 'postgres'),
            )
        elif self.db_type == 'sqlite':
            database_path = self.connection_params.get('database')
            if not database_path:
                raise ValueError('La ruta de la base SQLite es obligatoria')
            conn_string = f"sqlite:///{database_path}"
        else:
            raise ValueError(f"Unsupported database type: {self.db_type}")
            
        return create_engine(conn_string, pool_pre_ping=True, future=True)

    def _validate_identifier(self, value, label):
        if not value or not self.IDENTIFIER_PATTERN.match(value):
            raise ValueError(f'{label} inválido')
        return value

    def _qualified_table_name(self, database_name, table_name):
        safe_table = self._validate_identifier(table_name, 'table_name')

        if self.db_type == 'sqlite':
            return safe_table

        safe_database = self._validate_identifier(database_name, 'database_name')
        return f'{safe_database}.{safe_table}'
        
    def test_connection(self):
        try:
            with self.engine.connect() as connection:
                result = connection.execute(text('SELECT 1'))
                return result.scalar() == 1
        except Exception as e:
            logger.warning("Connection test failed: %s", e)
            return False
        
    def list_databases(self):
        with self.engine.connect() as connection:
            if self.db_type == 'mysql':
                result = connection.execute(text('SHOW DATABASES'))
                return [row[0] for row in result.fetchall()]
            if self.db_type == 'postgresql':
                result = connection.execute(
                    text("SELECT datname FROM pg_database WHERE datistemplate = false")
                )
                return [row[0] for row in result.fetchall()]
            return inspect(self.engine).get_table_names()

    def execute_query(self, query, params=None):
        with self.engine.begin() as connection:
            result = connection.execute(text(query), params or {})
            return result

    def execute_safe_update(self, database_name, table_name, primary_key, updates, pk_column='id'):
        safe_pk_column = self._validate_identifier(pk_column, 'pk_column')
        qualified_table_name = self._qualified_table_name(database_name, table_name)

        assignments = []
        params = {'pk_value': primary_key}
        for index, (column, value) in enumerate(updates.items()):
            safe_column = self._validate_identifier(column, 'column')
            param_name = f'value_{index}'
            assignments.append(f'{safe_column} = :{param_name}')
            params[param_name] = value

        if not assignments:
            raise ValueError('No hay columnas para actualizar')

        query = text(
            f'UPDATE {qualified_table_name} '
            f'SET {", ".join(assignments)} '
            f'WHERE {safe_pk_column} = :pk_value'
        )

        with self.engine.begin() as connection:
            result = connection.execute(query, params)
            return result.rowcount
        
    # More methods for database operations...
