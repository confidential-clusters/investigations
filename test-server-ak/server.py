from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import sys
import os

class PUTHandler(BaseHTTPRequestHandler):
    def do_PUT(self):
        content_length = int(self.headers['Content-Length'])
        body = self.rfile.read(content_length)
        print(body)
        try:
            data = json.loads(body)

            attestation_key = data.get('attestation_key', '')

            if not os.path.exists('/data/test.pub'):
                os.makedirs('/data', exist_ok=True)
                open('/data/test.pub', 'a').close()
                print("Created /data/test.pub")

            with open('/data/test.pub', 'w') as f:
                f.write(attestation_key)

            print(f"Successfully wrote attestation key to /data/test.pub")

            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'status': 'success'}).encode())
        except Exception as e:
            print(f"Error: {e}")
            self.send_response(500)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'status': 'error', 'message': str(e)}).encode())

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 5000), PUTHandler)
    print('Server running on port 5000...')
    server.serve_forever()
