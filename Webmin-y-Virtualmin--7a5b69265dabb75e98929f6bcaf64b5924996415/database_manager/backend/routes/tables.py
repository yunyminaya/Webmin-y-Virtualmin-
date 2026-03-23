from flask import Blueprint, current_app, request, jsonify
from services.database_service import DatabaseService
from models import Permission, SavedConnection, db
from security import permission_required

# Initialize blueprint
tables_bp = Blueprint('tables', __name__)

@tables_bp.route('/<connection_id>/<database_name>/<table_name>/update', methods=['POST'])
@permission_required(Permission.EDIT)  # Require EDIT permission
def update_record(connection_id, database_name, table_name):
    data = request.get_json(silent=True) or {}
    primary_key = data.get('primaryKey')
    updates = data.get('updates')

    if not isinstance(updates, dict) or not updates:
        return jsonify({'success': False, 'error': 'updates debe ser un objeto no vacío'}), 400

    if primary_key is None:
        return jsonify({'success': False, 'error': 'primaryKey es obligatorio'}), 400
    
    try:
        saved_connection = db.session.get(SavedConnection, int(connection_id))
        if not saved_connection:
            return jsonify({'success': False, 'error': 'Conexión no encontrada'}), 404

        if (
            saved_connection.database
            and saved_connection.db_type != 'sqlite'
            and saved_connection.database != database_name
        ):
            return jsonify({'success': False, 'error': 'Base de datos no autorizada para esta conexión'}), 403

        connection_params = {
            'host': saved_connection.host,
            'port': saved_connection.port,
            'username': saved_connection.username,
            'password': saved_connection.password,
            'database': saved_connection.database,
        }

        db_service = DatabaseService(
            saved_connection.db_type,
            connection_params,
            allowed_hosts=current_app.config.get('ALLOWED_DB_HOSTS', []),
        )
        rows_affected = db_service.execute_safe_update(
            database_name=saved_connection.database or database_name,
            table_name=table_name,
            primary_key=primary_key,
            updates=updates,
        )

        return jsonify({'success': True, 'rows_affected': rows_affected, 'connection_id': connection_id}), 200
    except ValueError:
        return jsonify({'success': False, 'error': 'Identificador de conexión inválido'}), 400
    except Exception:
        current_app.logger.exception('No fue posible actualizar el registro')
        return jsonify({'success': False, 'error': 'No fue posible actualizar el registro'}), 500

# Similar routes for insert and delete...
