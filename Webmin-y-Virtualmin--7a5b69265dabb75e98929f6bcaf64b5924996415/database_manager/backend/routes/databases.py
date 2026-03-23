from flask import Blueprint, request, jsonify
from services.database_service import DatabaseService
from models import Permission
from security import permission_required

# Initialize blueprint
databases_bp = Blueprint('databases', __name__)

@databases_bp.route('/connect', methods=['POST'])
@permission_required(Permission.VIEW)
def connect():
    data = request.get_json(silent=True) or {}
    db_type = data.get('db_type')
    connection_params = data.get('connection_params') or {}

    if not db_type or not isinstance(connection_params, dict):
        return jsonify({'status': 'error', 'message': 'db_type y connection_params son obligatorios'}), 400
    
    try:
        # Create database service
        db_service = DatabaseService(db_type, connection_params)
        
        # Test connection
        if db_service.test_connection():
            return jsonify({'status': 'success', 'message': 'Connection successful'}), 200
        else:
            return jsonify({'status': 'error', 'message': 'Connection failed'}), 400
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@databases_bp.route('/databases', methods=['GET'])
@permission_required(Permission.VIEW)
def list_databases():
    data = request.get_json(silent=True) or {}
    db_type = data.get('db_type')
    connection_params = data.get('connection_params') or {}

    if not db_type or not isinstance(connection_params, dict):
        return jsonify({'status': 'error', 'message': 'db_type y connection_params son obligatorios'}), 400

    try:
        db_service = DatabaseService(db_type, connection_params)
        return jsonify({'status': 'success', 'databases': db_service.list_databases()}), 200
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

# More routes for database operations...
