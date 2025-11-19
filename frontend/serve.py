#!/usr/bin/env python3
"""
Simple HTTP server for serving the ROSCA frontend locally.
Usage: python serve.py [port]
Default port: 8000
"""

import sys
import os
from http.server import HTTPServer, SimpleHTTPRequestHandler
import webbrowser

class ROSCAHTTPRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        # Add CORS headers for local development
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

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