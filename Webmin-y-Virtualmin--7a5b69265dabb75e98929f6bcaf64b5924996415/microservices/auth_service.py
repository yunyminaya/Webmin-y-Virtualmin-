import os
from typing import Optional

from flask import Flask, jsonify, request
from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer
from werkzeug.security import check_password_hash, generate_password_hash


app = Flask(__name__)
app.config['AUTH_SECRET_KEY'] = os.getenv('AUTH_SECRET_KEY', 'change-this-development-key')
app.config['AUTH_TOKEN_TTL'] = int(os.getenv('AUTH_TOKEN_TTL', '3600'))

DEFAULT_USERNAME = os.getenv('AUTH_ADMIN_USERNAME', 'admin')
DEFAULT_PASSWORD_HASH = generate_password_hash(
    os.getenv('AUTH_ADMIN_PASSWORD', 'change-me-now-please')
)

USERS = {
    DEFAULT_USERNAME: {
        'password_hash': DEFAULT_PASSWORD_HASH,
        'role': 'admin',
    }
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
