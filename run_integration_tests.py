#!/usr/bin/env python3
"""
Simple script to run ROSCA integration tests and generate results
Can be called from the frontend
"""

import sys
import subprocess
import json

def main():
    print("Running ROSCA integration tests...")
    
    try:
        # Run the integration test script
        result = subprocess.run(
            ["python3", "test_rosca_integration.py"],
            cwd="/home/robvox/evolve-deployment",
            capture_output=True,
            text=True,
            timeout=120
        )
        
        print(result.stdout)
        if result.stderr:
            print(result.stderr, file=sys.stderr)
        
        sys.exit(result.returncode)
        
    except subprocess.TimeoutExpired:
        print("Error: Tests timed out after 120 seconds")
        sys.exit(1)
    except Exception as e:
        print(f"Error running tests: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
