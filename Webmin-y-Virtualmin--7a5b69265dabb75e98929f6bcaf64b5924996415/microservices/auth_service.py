import os
from typing import Optional

from flask import Flask, jsonify, request
from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer
from werkzeug.security import check_password_hash, generate_password_hash


app = Flask(__name__)
APP_ENV = os.getenv('APP_ENV', 'development').lower()
IS_PRODUCTION = APP_ENV == 'production'


def _required_env(name, default=None):
    value = os.getenv(name)
    if value:
        return value
    if IS_PRODUCTION and default is None:
        raise RuntimeError(f'{name} es obligatorio cuando APP_ENV=production')
    return default


app.config['AUTH_SECRET_KEY'] = _required_env(
    'AUTH_SECRET_KEY',
    default=None,
)
app.config['AUTH_TOKEN_TTL'] = int(os.getenv('AUTH_TOKEN_TTL', '3600'))

DEFAULT_USERNAME = os.getenv('AUTH_ADMIN_USERNAME', '').strip()
DEFAULT_PASSWORD = os.getenv('AUTH_ADMIN_PASSWORD', '')

if IS_PRODUCTION and (not DEFAULT_USERNAME or not DEFAULT_PASSWORD):
    raise RuntimeError('AUTH_ADMIN_USERNAME y AUTH_ADMIN_PASSWORD son obligatorios cuando APP_ENV=production')

USERS = {}
if DEFAULT_USERNAME and DEFAULT_PASSWORD:
    USERS[DEFAULT_USERNAME] = {
        'password_hash': generate_password_hash(DEFAULT_PASSWORD),
        'role': 'admin',
    }


def _serializer() -> URLSafeTimedSerializer:
    return URLSafeTimedSerializer(app.config['AUTH_SECRET_KEY'], salt='auth-service')


def generate_token(username: str, role: str) -> str:
    return _serializer().dumps({'username': username, 'role': role})


def verify_token(token: str) -> Optional[dict]:
    try:
        return _serializer().loads(token, max_age=app.config['AUTH_TOKEN_TTL'])
    except (BadSignature, SignatureExpired):
        return None


@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok'}), 200


@app.route('/login', methods=['POST'])
def login():
    if not USERS:
        return jsonify({'error': 'Servicio de autenticación no configurado'}), 503

    data = request.get_json(silent=True) or {}
    username = (data.get('username') or '').strip()
    password = data.get('password') or ''

    if not username or not password:
        return jsonify({'error': 'username y password son obligatorios'}), 400

    user = USERS.get(username)
    if not user or not check_password_hash(user['password_hash'], password):
        return jsonify({'error': 'Credenciales inválidas'}), 401

    token = generate_token(username, user['role'])
    return jsonify({
        'token': token,
        'token_type': 'Bearer',
        'expires_in': app.config['AUTH_TOKEN_TTL'],
        'role': user['role'],
    }), 200


@app.route('/validate', methods=['POST'])
def validate():
    auth_header = request.headers.get('Authorization', '')
    if not auth_header.startswith('Bearer '):
        return jsonify({'error': 'Token Bearer requerido'}), 401

    payload = verify_token(auth_header.split(' ', 1)[1].strip())
    if not payload:
        return jsonify({'error': 'Token inválido o expirado'}), 401

    return jsonify(payload), 200


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
