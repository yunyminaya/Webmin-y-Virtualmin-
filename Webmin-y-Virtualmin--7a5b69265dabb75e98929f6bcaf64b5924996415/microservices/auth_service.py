from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/login', methods=['POST'])
def login():
    return jsonify({'token': 'secure_jwt_token'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
