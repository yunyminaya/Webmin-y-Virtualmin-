import time

from flask import Blueprint, current_app, g, jsonify, request
from werkzeug.security import generate_password_hash, check_password_hash
from models import Role, User, db
from security import generate_access_token, token_required

# Initialize blueprint
auth_bp = Blueprint('auth', __name__)
LOGIN_ATTEMPTS = {}


def _rate_limit_key(username):
    forwarded_for = request.headers.get('X-Forwarded-For', '')
    client_ip = forwarded_for.split(',', 1)[0].strip() or request.remote_addr or 'unknown'
    return f"{client_ip}:{username.lower()}"


def _is_locked(key):
    record = LOGIN_ATTEMPTS.get(key)
    now = time.time()
    if not record:
        return False

    locked_until = record.get('locked_until', 0)
    if locked_until > now:
        return True

    window_seconds = current_app.config['LOGIN_RATE_LIMIT_WINDOW_SECONDS']
    if record.get('window_start', 0) + window_seconds <= now:
        LOGIN_ATTEMPTS.pop(key, None)

    return False


def _register_failed_attempt(key):
    now = time.time()
    window_seconds = current_app.config['LOGIN_RATE_LIMIT_WINDOW_SECONDS']
    max_attempts = current_app.config['LOGIN_RATE_LIMIT_ATTEMPTS']
    lockout_seconds = current_app.config['LOGIN_LOCKOUT_SECONDS']
    record = LOGIN_ATTEMPTS.get(key)

    if not record or record.get('window_start', 0) + window_seconds <= now:
        record = {'count': 0, 'window_start': now, 'locked_until': 0}

    record['count'] += 1
    if record['count'] >= max_attempts:
        record['locked_until'] = now + lockout_seconds

    LOGIN_ATTEMPTS[key] = record


def _clear_failed_attempts(key):
    LOGIN_ATTEMPTS.pop(key, None)

@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json(silent=True) or {}
    username = (data.get('username') or '').strip()
    password = data.get('password') or ''

    if not username or not password:
        return jsonify({'error': 'Usuario y contraseña son obligatorios'}), 400

    rate_limit_key = _rate_limit_key(username)
    if _is_locked(rate_limit_key):
        return jsonify({'error': 'Demasiados intentos fallidos. Intenta más tarde'}), 429
    
    user = User.query.filter_by(username=username).first()
    
    if not user or not check_password_hash(user.password, password):
        _register_failed_attempt(rate_limit_key)
        return jsonify({'error': 'Credenciales inválidas'}), 401

    _clear_failed_attempts(rate_limit_key)
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

    if len(username) < 3:
        return jsonify({'error': 'El usuario debe tener al menos 3 caracteres'}), 400

    if len(password) < 12:
        return jsonify({'error': 'La contraseña debe tener al menos 12 caracteres'}), 400
    
    if User.query.filter_by(username=username).first():
        return jsonify({'error': 'Username already exists'}), 400

    editor_role = Role.query.filter_by(name='editor').first()
    if not editor_role:
        return jsonify({'error': 'Rol editor no configurado'}), 500
         
    new_user = User(
        username=username,
        password=generate_password_hash(password),
        role_id=editor_role.id
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
