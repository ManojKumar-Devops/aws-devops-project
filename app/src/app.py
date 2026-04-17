import os
import time
import logging
from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import psycopg2
from psycopg2.extras import RealDictCursor

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(name)s %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

REQUEST_COUNT = Counter(
    'app_request_count_total',
    'Total request count',
    ['method', 'endpoint', 'status']
)
REQUEST_LATENCY = Histogram(
    'app_request_latency_seconds',
    'Request latency in seconds',
    ['endpoint']
)


def get_db_connection():
    return psycopg2.connect(
        host=os.getenv('DB_HOST', 'localhost'),
        port=os.getenv('DB_PORT', '5432'),
        database=os.getenv('DB_NAME', 'appdb'),
        user=os.getenv('DB_USER', 'appuser'),
        password=os.getenv('DB_PASSWORD', 'password')
    )


@app.before_request
def start_timer():
    request.start_time = time.time()


@app.after_request
def record_metrics(response):
    latency = time.time() - request.start_time
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.path,
        status=response.status_code
    ).inc()
    REQUEST_LATENCY.labels(endpoint=request.path).observe(latency)
    return response


@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        'status': 'healthy',
        'version': os.getenv('APP_VERSION', '1.0.0'),
        'environment': os.getenv('ENVIRONMENT', 'development')
    }), 200


@app.route('/ready', methods=['GET'])
def readiness():
    try:
        conn = get_db_connection()
        conn.close()
        return jsonify({'status': 'ready'}), 200
    except Exception as e:
        logger.error(f"Readiness check failed: {e}")
        return jsonify({'status': 'not ready', 'error': str(e)}), 503


@app.route('/metrics', methods=['GET'])
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}


@app.route('/api/v1/items', methods=['GET'])
def get_items():
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM items ORDER BY created_at DESC LIMIT 100")
        items = cur.fetchall()
        cur.close()
        conn.close()
        return jsonify({'items': [dict(item) for item in items], 'count': len(items)}), 200
    except Exception as e:
        logger.error(f"Error fetching items: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/v1/items', methods=['POST'])
def create_item():
    data = request.get_json()
    if not data or 'name' not in data:
        return jsonify({'error': 'name is required'}), 400
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            "INSERT INTO items (name, description) VALUES (%s, %s) RETURNING *",
            (data['name'], data.get('description', ''))
        )
        item = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()
        return jsonify(dict(item)), 201
    except Exception as e:
        logger.error(f"Error creating item: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/v1/items/<int:item_id>', methods=['GET'])
def get_item(item_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM items WHERE id = %s", (item_id,))
        item = cur.fetchone()
        cur.close()
        conn.close()
        if not item:
            return jsonify({'error': 'Item not found'}), 404
        return jsonify(dict(item)), 200
    except Exception as e:
        logger.error(f"Error fetching item: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/v1/items/<int:item_id>', methods=['PUT'])
def update_item(item_id):
    data = request.get_json()
    if not data:
        return jsonify({'error': 'Request body required'}), 400
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            "UPDATE items SET name=%s, description=%s, updated_at=NOW() WHERE id=%s RETURNING *",
            (data.get('name'), data.get('description'), item_id)
        )
        item = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()
        if not item:
            return jsonify({'error': 'Item not found'}), 404
        return jsonify(dict(item)), 200
    except Exception as e:
        logger.error(f"Error updating item: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/v1/items/<int:item_id>', methods=['DELETE'])
def delete_item(item_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("DELETE FROM items WHERE id=%s RETURNING id", (item_id,))
        deleted = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()
        if not deleted:
            return jsonify({'error': 'Item not found'}), 404
        return jsonify({'message': f'Item {item_id} deleted'}), 200
    except Exception as e:
        logger.error(f"Error deleting item: {e}")
        return jsonify({'error': 'Internal server error'}), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.getenv('PORT', '5000')), debug=False)  # nosec B104
