import pytest
import json
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../src'))

from unittest.mock import patch, MagicMock


@pytest.fixture
def client():
    with patch('app.get_db_connection') as mock_db:
        mock_conn = MagicMock()
        mock_cur = MagicMock()
        mock_db.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cur
        mock_cur.__enter__ = lambda s: s
        mock_cur.__exit__ = MagicMock(return_value=False)

        from app import app
        app.config['TESTING'] = True
        with app.test_client() as client:
            yield client, mock_db, mock_cur


def test_health_endpoint(client):
    c, _, _ = client
    response = c.get('/health')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['status'] == 'healthy'


def test_health_returns_version(client):
    c, _, _ = client
    response = c.get('/health')
    data = json.loads(response.data)
    assert 'version' in data
    assert 'environment' in data


def test_create_item_missing_name(client):
    c, _, _ = client
    response = c.post('/api/v1/items',
                      data=json.dumps({'description': 'test'}),
                      content_type='application/json')
    assert response.status_code == 400
    data = json.loads(response.data)
    assert 'error' in data


def test_create_item_no_body(client):
    c, _, _ = client
    response = c.post('/api/v1/items',
                      data='',
                      content_type='application/json')
    assert response.status_code == 400


def test_metrics_endpoint(client):
    c, _, _ = client
    response = c.get('/metrics')
    assert response.status_code == 200


def test_readiness_success(client):
    c, mock_db, _ = client
    mock_db.return_value = MagicMock()
    response = c.get('/ready')
    assert response.status_code == 200


def test_readiness_failure(client):
    c, mock_db, _ = client
    mock_db.side_effect = Exception("DB unreachable")
    response = c.get('/ready')
    assert response.status_code == 503
