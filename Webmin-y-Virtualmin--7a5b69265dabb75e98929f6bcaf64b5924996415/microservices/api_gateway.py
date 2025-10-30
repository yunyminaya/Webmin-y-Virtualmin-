from flask import Flask, jsonify, request
import requests

app = Flask(__name__)

SERVICES = {
    'auth': 'http://auth-service:5000',
    'dns': 'http://dns-service:5000',
    'web': 'http://web-service:5000',
    'email': 'http://email-service:5000'
}

@app.route('/<service_name>/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE'])
def gateway(service_name, path):
    if service_name not in SERVICES:
        return jsonify({'error': 'Service not found'}), 404
    
    url = f"{SERVICES[service_name]}/{path}"
    response = requests.request(
        method=request.method,
        url=url,
        headers=request.headers,
        data=request.get_data(),
        cookies=request.cookies,
        allow_redirects=False
    )
    
    return (response.content, response.status_code, response.headers.items())

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
