"""Shared pytest configuration — centralizes sys.path for all test modules."""
import os
import sys

# Insert scripts directory once for all test modules
_scripts = os.path.join(os.path.dirname(__file__), "..", "src", "scripts")
if _scripts not in sys.path:
    sys.path.insert(0, _scripts)
