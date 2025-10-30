from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()

class SavedConnection(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    db_type = db.Column(db.String(20), nullable=False)
    host = db.Column(db.String(100))
    port = db.Column(db.Integer)
    username = db.Column(db.String(50))
    password = db.Column(db.String(100))  # Should be encrypted in real application
    database = db.Column(db.String(100))  # For SQLite, this is the file path

    def __repr__(self):
        return f'<Connection {self.name}>'

class Role(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50), unique=True, nullable=False)
    permissions = db.Column(db.Integer, nullable=False)

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password = db.Column(db.String(120), nullable=False)
    role_id = db.Column(db.Integer, db.ForeignKey('role.id'), nullable=False)
    
    role = db.relationship('Role', backref=db.backref('users', lazy=True))

# Permission flags
class Permission:
    VIEW = 1
    EDIT = 2
    DELETE = 4
    ADMIN = 8
