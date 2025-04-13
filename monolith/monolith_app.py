from flask import Flask, request, jsonify
import logging

# Configure basic logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

app = Flask(__name__)

# --- In-memory storage (simulating databases) ---
users = {} # user_id -> username
products = { # product_id -> product_details
    "prod123": {"name": "Laptop", "price": 1200},
    "prod456": {"name": "Mouse", "price": 25},
}
orders = [] # list of orders

user_counter = 0

# --- User Functionality ---
@app.route('/user', methods=['POST'])
def create_user():
    global user_counter
    data = request.get_json()
    if not data or 'username' not in data:
        logging.warning("Create user request failed: Missing username")
        return jsonify({"error": "Username is required"}), 400
    user_counter += 1
    user_id = f"user{user_counter}"
    users[user_id] = data['username']
    logging.info(f"[Monolith] Created user: {user_id} -> {data['username']}")
    logging.info(f"[Monolith] Current Users: {users}")
    return jsonify({"user_id": user_id, "username": data['username']}), 201

# --- Product Functionality ---
@app.route('/product/<string:product_id>', methods=['GET'])
def get_product(product_id):
    product = products.get(product_id)
    if product:
        logging.info(f"[Monolith] Product found: {product_id}")
        return jsonify(product), 200
    else:
        logging.warning(f"[Monolith] Product not found: {product_id}")
        return jsonify({"error": "Product not found"}), 404

# --- Order Functionality ---
@app.route('/order', methods=['POST'])
def create_order():
    data = request.get_json()
    if not data or 'user_id' not in data or 'product_id' not in data:
        logging.warning("Create order request failed: Missing user_id or product_id")
        return jsonify({"error": "user_id and product_id are required"}), 400

    user_id = data['user_id']
    product_id = data['product_id']

    # Check if user exists (internal check)
    if user_id not in users:
        logging.warning(f"[Monolith] Order failed: User not found {user_id}")
        return jsonify({"error": f"User '{user_id}' not found"}), 404

    # Check if product exists (internal check)
    if product_id not in products:
        logging.warning(f"[Monolith] Order failed: Product not found {product_id}")
        return jsonify({"error": f"Product '{product_id}' not found"}), 404

    # Create the order (simulated)
    order = {
        "order_id": f"ord{len(orders)+1}",
        "user_id": user_id,
        "product_id": product_id,
        "status": "created"
    }
    orders.append(order)
    logging.info(f"[Monolith] Order created: {order}")
    logging.info(f"[Monolith] All Orders: {orders}")
    return jsonify(order), 201

@app.route('/health', methods=['GET'])
def health_check():
    # Basic health check endpoint
    return jsonify({"status": "UP"}), 200

if __name__ == '__main__':
    # Important: host='0.0.0.0' to be accessible outside the container
    # Gunicorn is typically used via the CMD in Dockerfile
    logging.info("Starting Monolith Flask app (for local dev)")
    app.run(debug=True, host='0.0.0.0', port=5000)