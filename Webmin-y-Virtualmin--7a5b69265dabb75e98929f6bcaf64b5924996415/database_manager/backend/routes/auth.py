from flask import Blueprint, current_app, g, jsonify, request
from werkzeug.security import generate_password_hash, check_password_hash
from models import User, db
from security import generate_access_token, token_required

# Initialize blueprint
auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json(silent=True) or {}
    username = (data.get('username') or '').strip()
    password = data.get('password') or ''

    if not username or not password:
        return jsonify({'error': 'Usuario y contraseña son obligatorios'}), 400
    
    user = User.query.filter_by(username=username).first()
    
    if not user or not check_password_hash(user.password, password):
        return jsonify({'error': 'Credenciales inválidas'}), 401

    token = generate_access_token(user)
    return jsonify({
        'message': 'Login successful',
        'token': token,
        'token_type': 'Bearer',
        'expires_in': current_app.config['AUTH_TOKEN_MAX_AGE'],
        'user': {
            'id': user.id,
            'username': user.username,
            'role': user.role.name if user.role else None,
        }
    })

@auth_bp.route('/register', methods=['POST'])
def register():
    if not current_app.config.get('ALLOW_PUBLIC_REGISTRATION', False):
        return jsonify({'error': 'Registro público deshabilitado'}), 403

    data = request.get_json(silent=True) or {}
    username = (data.get('username') or '').strip()
    password = data.get('password') or ''
    role_id = data.get('role_id', 2)  # Default to editor role

    if len(username) < 3:
        return jsonify({'error': 'El usuario debe tener al menos 3 caracteres'}), 400

    if len(password) < 12:
        return jsonify({'error': 'La contraseña debe tener al menos 12 caracteres'}), 400
    
    if User.query.filter_by(username=username).first():
        return jsonify({'error': 'Username already exists'}), 400
         
    new_user = User(
        username=username,
        password=generate_password_hash(password),
        role_id=role_id
    )
    
    db.session.add(new_user)
    db.session.commit()
    
    return jsonify({'message': 'User created successfully', 'user_id': new_user.id})


@auth_bp.route('/me', methods=['GET'])
@token_required
def me():
    return jsonify({
        'id': g.current_user.id,
        'username': g.current_user.username,
        'role': g.current_user.role.name if g.current_user.role else None,
    })
