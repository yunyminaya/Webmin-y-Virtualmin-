from flask import Flask, g, request, jsonify
from flask_cors import CORS
from functools import wraps

app = Flask(__name__)
CORS(app)

# Load configuration
app.config.from_pyfile('config.py')

# Register blueprints
from routes.auth import auth_bp
from routes.databases import databases_bp
from routes.tables import tables_bp

app.register_blueprint(auth_bp)
app.register_blueprint(databases_bp)
app.register_blueprint(tables_bp)

# Permission flags
class Permission:
    VIEW = 1
    EDIT = 2
    DELETE = 4
    ADMIN = 8

def permission_required(permission):
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            # Check user permissions
            # In a real app, you would get the current user from the session
            # For demo purposes, we'll assume a user with full permissions
            if not Permission.ADMIN & permission:
                return jsonify({'error': 'Insufficient permissions'}), 403
            return f(*args, **kwargs)
        return decorated_function
    return decorator

# Apply to routes
@tables_bp.route('/update', methods=['POST'])
@permission_required(Permission.EDIT)
def update_record():
    # ... implementation ...

if __name__ == '__main__':
    app.run(debug=True)
