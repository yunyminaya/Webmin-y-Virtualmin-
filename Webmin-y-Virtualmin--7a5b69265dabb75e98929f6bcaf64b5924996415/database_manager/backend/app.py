import logging
import os

from flask import Flask, jsonify
from flask_cors import CORS
from werkzeug.security import generate_password_hash

from config import Config
from models import Permission, Role, User, db
from routes.auth import auth_bp
from routes.databases import databases_bp
from routes.tables import tables_bp


def configure_logging(app):
    log_level = logging.DEBUG if app.config.get("DEBUG") else logging.INFO
    logging.basicConfig(
        level=log_level,
        format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
    )


def seed_roles():
    role_map = {
        "viewer": Permission.VIEW,
        "editor": Permission.VIEW | Permission.EDIT,
        "admin": Permission.VIEW | Permission.EDIT | Permission.DELETE | Permission.ADMIN,
    }

    for name, permissions in role_map.items():
        existing_role = Role.query.filter_by(name=name).first()
        if existing_role:
            existing_role.permissions = permissions
            continue

        db.session.add(Role(name=name, permissions=permissions))

    db.session.commit()


def bootstrap_admin(app):
    if not app.config.get("ENABLE_BOOTSTRAP_ADMIN", False):
        app.logger.info("Bootstrap admin deshabilitado")
        return

    username = app.config.get("BOOTSTRAP_ADMIN_USERNAME")
    password = app.config.get("BOOTSTRAP_ADMIN_PASSWORD")
    if not username or not password:
        return

    existing_user = User.query.filter_by(username=username).first()
    if existing_user:
        return

    admin_role = Role.query.filter_by(name="admin").first()
    if not admin_role:
        return

    db.session.add(
        User(
            username=username,
            password=generate_password_hash(password),
            role_id=admin_role.id,
        )
    )
    db.session.commit()
    app.logger.info("Usuario administrador inicial creado")


def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    configure_logging(app)

    db.init_app(app)

    cors_origins = app.config.get("CORS_ORIGINS") or []
    CORS(
        app,
        resources={r"/*": {"origins": cors_origins}} if cors_origins else {},
        supports_credentials=False,
    )

    app.register_blueprint(auth_bp, url_prefix="/api/auth")
    app.register_blueprint(databases_bp, url_prefix="/api/databases")
    app.register_blueprint(tables_bp, url_prefix="/api/tables")

    @app.get("/health")
    def health_check():
        return jsonify({"status": "ok"}), 200

    with app.app_context():
        db.create_all()
        seed_roles()
        bootstrap_admin(app)

    return app


app = create_app()


if __name__ == '__main__':
    app.run(
        host=os.getenv("APP_HOST", "0.0.0.0"),
        port=int(os.getenv("APP_PORT", "5000")),
        debug=app.config.get("DEBUG", False),
    )
