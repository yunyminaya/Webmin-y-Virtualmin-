from functools import wraps

from flask import current_app, g, jsonify, request
from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer

from models import Permission, User, db


def _get_serializer():
    return URLSafeTimedSerializer(
        current_app.config["JWT_SECRET_KEY"],
        salt=current_app.config["JWT_SALT"],
    )


def generate_access_token(user):
    payload = {
        "user_id": user.id,
        "username": user.username,
        "permissions": user.role.permissions if user.role else Permission.VIEW,
    }
    return _get_serializer().dumps(payload)


def verify_access_token(token):
    try:
        data = _get_serializer().loads(
            token,
            max_age=current_app.config["AUTH_TOKEN_MAX_AGE"],
        )
    except SignatureExpired:
        return None, "Token expirado"
    except BadSignature:
        return None, "Token inválido"

    user = db.session.get(User, data.get("user_id"))
    if not user:
        return None, "Usuario no encontrado"

    return user, None


def token_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return jsonify({"error": "Se requiere token Bearer"}), 401

        token = auth_header.split(" ", 1)[1].strip()
        user, error = verify_access_token(token)
        if error:
            return jsonify({"error": error}), 401

        g.current_user = user
        return f(*args, **kwargs)

    return decorated_function


def permission_required(permission):
    def decorator(f):
        @wraps(f)
        @token_required
        def decorated_function(*args, **kwargs):
            current_user = getattr(g, "current_user", None)
            user_permissions = (
                current_user.role.permissions
                if current_user and current_user.role
                else Permission.VIEW
            )

            if (user_permissions & permission) != permission:
                return jsonify({"error": "Permisos insuficientes"}), 403

            return f(*args, **kwargs)

        return decorated_function

    return decorator
