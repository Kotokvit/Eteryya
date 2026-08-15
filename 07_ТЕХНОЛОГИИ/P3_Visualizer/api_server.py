#!/usr/bin/env python3
"""Simple API server for DYNAMIS P³ computations."""
import json
import sys
import os
from http.server import HTTPServer, BaseHTTPRequestHandler

sys.path.insert(0, '/dynamis/kernel')
from p3_kernel import HomVec4, fs_distance, w_from_distance, K_ANISO

class DynamisAPI(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/api/health':
            self._json(200, {'status': 'ok', 'version': '3.0'})
        elif self.path == '/api/constants':
            self._json(200, {
                'R_eteria_km': 5838.4,
                'R_earth_km': 6378.0,
                'K_aniso': float(K_ANISO),
                'resonance_hz': 18.7,
            })
        elif self.path.startswith('/api/fs_distance'):
            # ?x1=...&y1=...&z1=...&w1=...&x2=...&...
            params = self._parse_params()
            p1 = HomVec4(params['x1'], params['y1'], params['z1'], params['w1']).normalize()
            p2 = HomVec4(params['x2'], params['y2'], params['z2'], params['w2']).normalize()
            d = fs_distance(p1, p2)
            self._json(200, {'d_fs': d, 'd_fs_deg': d * 180 / 3.141592653589793})
        else:
            self._json(404, {'error': 'not found'})
    
    def _parse_params(self):
        from urllib.parse import parse_qs
        qs = parse_qs(self.path.split('?')[1] if '?' in self.path else '')
        return {k: float(v[0]) for k, v in qs.items()}
    
    def _json(self, code, data):
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

if __name__ == '__main__':
    print("DYNAMIS API server on :8000")
    HTTPServer(('0.0.0.0', 8000), DynamisAPI).serve_forever()
