# comparative-demo/microservices/order_service/order_service.py
# (Corrected Version)

import os
from flask import Flask, request, jsonify
import requests # To call other services
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - [OrderSvc] %(message)s')

app = Flask(__name__)

orders = []

# --- Service Discovery for Kubernetes ---
# Default to Kubernetes service names. Format: http://<service-name>:<port>
# These names MUST match the 'name' field in the Kubernetes Service manifests.
USER_SERVICE_HOST = os.environ.get("USER_SERVICE_HOST", "user-service")
# We will use the known service port directly, ignoring the environment variable
# USER_SERVICE_PORT = os.environ.get("USER_SERVICE_PORT", "5001") # <<<--- OLD LINE (REMOVED)
PRODUCT_SERVICE_HOST = os.environ.get("PRODUCT_SERVICE_HOST", "product-service")
# We will use the known service port directly, ignoring the environment variable
# PRODUCT_SERVICE_PORT = os.environ.get("PRODUCT_SERVICE_PORT", "5002") # <<<--- OLD LINE (REMOVED)

# Construct URLs using the reliable service name and the known service port
USER_SERVICE_URL = f"http://{USER_SERVICE_HOST}:5001" # <<<--- CORRECTED: Use hardcoded port 5001
PRODUCT_SERVICE_URL = f"http://{PRODUCT_SERVICE_HOST}:5002" # <<<--- CORRECTED: Use hardcoded port 5002

logging.info(f"Using User Service URL: {USER_SERVICE_URL}")
logging.info(f"Using Product Service URL: {PRODUCT_SERVICE_URL}")

@app.route('/order', methods=['POST'])
def create_order():
    data = request.get_json()
    if not data or 'user_id' not in data or 'product_id' not in data:
        logging.warning("Create order failed: Missing user_id or product_id")
        return jsonify({"error": "user_id and product_id are required"}), 400

    user_id = data['user_id']
    product_id = data['product_id']

    # --- Call User Service to check user ---
    try:
        # Use the correctly constructed URL
        url_to_call = f"{USER_SERVICE_URL}/user/{user_id}"
        logging.info(f"Calling User Service at {url_to_call}")
        user_response = requests.get(url_to_call, timeout=5) # Added timeout
        if user_response.status_code == 404:
            logging.warning(f"User check failed: User '{user_id}' not found (from User Service)")
            return jsonify({"error": f"User '{user_id}' not found"}), 404
        user_response.raise_for_status() # Raise exceptions for other HTTP errors (5xx, 4xx)
        logging.info(f"User check OK for: {user_id}")
    except requests.exceptions.Timeout:
        logging.error(f"Timeout calling User Service at {url_to_call}")
        return jsonify({"error": "User service timed out"}), 504 # Gateway Timeout
    except requests.exceptions.ConnectionError:
        logging.error(f"Connection error calling User Service at {url_to_call}")
        return jsonify({"error": "Could not connect to user service"}), 503 # Service Unavailable
    except requests.exceptions.RequestException as e:
        logging.error(f"Error calling User Service at {url_to_call}: {e}")
        return jsonify({"error": "Failed to communicate with user service"}), 503 # Service Unavailable

    # --- Call Product Service to check product ---
    try:
        # Use the correctly constructed URL
        url_to_call = f"{PRODUCT_SERVICE_URL}/product/{product_id}"
        logging.info(f"Calling Product Service at {url_to_call}")
        product_response = requests.get(url_to_call, timeout=5) # Added timeout
        if product_response.status_code == 404:
            logging.warning(f"Product check failed: Product '{product_id}' not found (from Product Service)")
            return jsonify({"error": f"Product '{product_id}' not found"}), 404
        product_response.raise_for_status()
        logging.info(f"Product check OK for: {product_id}")
    except requests.exceptions.Timeout:
        logging.error(f"Timeout calling Product Service at {url_to_call}")
        return jsonify({"error": "Product service timed out"}), 504 # Gateway Timeout
    except requests.exceptions.ConnectionError:
        logging.error(f"Connection error calling Product Service at {url_to_call}")
        return jsonify({"error": "Could not connect to product service"}), 503 # Service Unavailable
    except requests.exceptions.RequestException as e:
        logging.error(f"Error calling Product Service at {url_to_call}: {e}")
        return jsonify({"error": "Failed to communicate with product service"}), 503 # Service Unavailable


    # Create the order (simulated)
    order = {
        "order_id": f"ord{len(orders)+1}",
        "user_id": user_id,
        "product_id": product_id,
        "status": "created"
    }
    orders.append(order)
    logging.info(f"Order created: {order}")
    # logging.info(f"All Orders: {orders}") # Optionally log all orders if needed for debug
    return jsonify(order), 201

@app.route('/health', methods=['GET'])
def health_check():
    # Could add checks to downstream services here for a more robust check
    return jsonify({"status": "UP"}), 200

if __name__ == '__main__':
    # This block is mainly for local development, not when running in Docker/K8s via Gunicorn
    logging.info("Starting Order Service Flask app (for local dev)")
    # The port here (5003) should match the targetPort in the K8s service and containerPort in the deployment
    app.run(debug=True, host='0.0.0.0', port=5003)