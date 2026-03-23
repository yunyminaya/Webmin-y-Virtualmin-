from flask import Blueprint, request, jsonify
from services.database_service import DatabaseService
from models import Permission
from security import permission_required

# Initialize blueprint
tables_bp = Blueprint('tables', __name__)

@tables_bp.route('/<connection_id>/<database_name>/<table_name>/update', methods=['POST'])
@permission_required(Permission.EDIT)  # Require EDIT permission
def update_record(connection_id, database_name, table_name):
    data = request.get_json(silent=True) or {}
    primary_key = data.get('primaryKey')
    updates = data.get('updates')
    db_type = data.get('db_type')
    connection_params = data.get('connection_params') or {}

    if not db_type:
        return jsonify({'success': False, 'error': 'db_type es obligatorio'}), 400

    if not isinstance(connection_params, dict):
        return jsonify({'success': False, 'error': 'connection_params debe ser un objeto'}), 400

    if not isinstance(updates, dict) or not updates:
        return jsonify({'success': False, 'error': 'updates debe ser un objeto no vacío'}), 400

    if primary_key is None:
        return jsonify({'success': False, 'error': 'primaryKey es obligatorio'}), 400
    
    try:
        db_service = DatabaseService(db_type, connection_params)
        rows_affected = db_service.execute_safe_update(
            database_name=database_name,
            table_name=table_name,
            primary_key=primary_key,
            updates=updates,
        )

        return jsonify({'success': True, 'rows_affected': rows_affected, 'connection_id': connection_id}), 200
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

# Similar routes for insert and delete...
