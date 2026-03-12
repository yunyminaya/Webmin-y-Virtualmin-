from flask import Blueprint, request, jsonify
from services.database_service import DatabaseService
from app import permission_required, Permission

# Initialize blueprint
tables_bp = Blueprint('tables', __name__)

@tables_bp.route('/<connection_id>/<database_name>/<table_name>/update', methods=['POST'])
@permission_required(Permission.EDIT)  # Require EDIT permission
def update_record(connection_id, database_name, table_name):
    data = request.get_json()
    primary_key = data.get('primaryKey')
    updates = data.get('updates')
    
    try:
        # Get database service
        # (In a real app, you'd retrieve the connection details from a database)
        db_service = DatabaseService('mysql', {
            'host': 'localhost',
            'port': 3306,
            'username': 'root',
            'password': ''
        })
        
        # Build and execute update query
        # (This is simplified - should use parameterized queries)
        set_clause = ', '.join([f"{k} = '{v}'" for k, v in updates.items()])
        query = f"UPDATE {database_name}.{table_name} SET {set_clause} WHERE id = {primary_key}"
        
        # Execute update
        db_service.execute_query(query)
        
        return jsonify({'success': True}), 200
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

# Similar routes for insert and delete...
