import pytest
import sys
import os

# Make sure app/src is importable from tests
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))
