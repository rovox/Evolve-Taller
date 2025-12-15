#!/usr/bin/env python3
"""
Simple HTTP server for serving the ROSCA frontend locally.
Usage: python serve.py [port]
Default port: 8000
"""

import sys
import os
import subprocess
import json

class ROSCAHTTPRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        # Add CORS headers for local development
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

    def do_POST(self):
        if self.path == '/run_tests':
            self.run_tests()
        else:
            self.send_error(404, "Endpoint not found")

    def run_tests(self):
        print("🧪 Received request to run integration tests...")
        try:
            # Execute the test script
            # We assume serve.py is in frontend/ and we need to run script in root
            root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            script_path = os.path.join(root_dir, "test_rosca_integration.py")
            
            result = subprocess.run(
                ["python3", script_path],
                cwd=root_dir,
                capture_output=True,
                text=True,
                timeout=120
            )
            
            if result.returncode == 0:
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                response = {"status": "success", "message": "Tests completed successfully", "output": result.stdout}
            else:
                self.send_response(500)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                response = {"status": "error", "message": "Tests failed", "output": result.stderr + "\n" + result.stdout}
                
            self.wfile.write(json.dumps(response).encode('utf-8'))
            
        except Exception as e:
            print(f"❌ Error running tests: {e}")
            self.send_response(500)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {"status": "error", "message": str(e)}
            self.wfile.write(json.dumps(response).encode('utf-8'))

def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    
    # Change to frontend directory
    frontend_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(frontend_dir)
    
    server_address = ('', port)
    httpd = HTTPServer(server_address, ROSCAHTTPRequestHandler)
    
    print(f"🏦 ROSCA Frontend Server")
    print(f"📍 Serving at: http://localhost:{port}")
    print(f"📁 Directory: {frontend_dir}")
    print(f"🔗 Opening browser...")
    print(f"⏹️  Press Ctrl+C to stop\n")
    
    # Open browser
    webbrowser.open(f'http://localhost:{port}')
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 Server stopped.")
        httpd.server_close()

if __name__ == '__main__':
    main()