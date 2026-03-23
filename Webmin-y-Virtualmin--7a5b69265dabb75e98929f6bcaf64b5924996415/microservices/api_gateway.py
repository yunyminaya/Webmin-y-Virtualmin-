import os

from flask import Flask, jsonify, request
import requests

app = Flask(__name__)
REQUEST_TIMEOUT = int(os.getenv('GATEWAY_REQUEST_TIMEOUT', '10'))
AUTH_SERVICE_VALIDATE_URL = os.getenv('AUTH_SERVICE_VALIDATE_URL', 'http://auth-service:5000/validate')
ALLOWED_FORWARD_HEADERS = {'authorization', 'content-type', 'accept', 'user-agent', 'x-request-id'}

SERVICES = {
    'auth': 'http://auth-service:5000',
    'dns': 'http://dns-service:5000',
    'web': 'http://web-service:5000',
    'email': 'http://email-service:5000'
}


def _is_public_route(service_name, path):
    normalized_path = path.strip('/')
    return service_name == 'auth' and normalized_path in {'login', 'health'}


def _validate_token(auth_header):
    try:
        response = requests.post(
            AUTH_SERVICE_VALIDATE_URL,
            headers={'Authorization': auth_header, 'Accept': 'application/json'},
            timeout=REQUEST_TIMEOUT,
        )
    except requests.RequestException:
        return None

    if response.status_code != 200:
        return None

    return response.json()

@app.route('/<service_name>/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE'])
def gateway(service_name, path):
    if service_name not in SERVICES:
        return jsonify({'error': 'Service not found'}), 404

    auth_header = request.headers.get('Authorization')
    if not _is_public_route(service_name, path) and not auth_header:
        return jsonify({'error': 'Authorization header required'}), 401

    if not _is_public_route(service_name, path):
        token_payload = _validate_token(auth_header)
        if not token_payload:
            return jsonify({'error': 'Unauthorized'}), 401
    
    url = f"{SERVICES[service_name]}/{path}"

    forwarded_headers = {
        key: value
        for key, value in request.headers.items()
        if key.lower() in ALLOWED_FORWARD_HEADERS
    }
    forwarded_headers['X-Forwarded-For'] = request.remote_addr or 'unknown'

    try:
        response = requests.request(
            method=request.method,
            url=url,
            headers=forwarded_headers,
            data=request.get_data(),
            cookies=request.cookies,
            allow_redirects=False,
            timeout=REQUEST_TIMEOUT,
        )
    except requests.RequestException as exc:
        return jsonify({'error': f'Upstream request failed: {exc}'}), 502
    
    excluded_headers = {'content-encoding', 'content-length', 'transfer-encoding', 'connection'}
    response_headers = [
        (name, value)
        for name, value in response.headers.items()
        if name.lower() not in excluded_headers
    ]

    return (response.content, response.status_code, response_headers)


@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok'}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)
