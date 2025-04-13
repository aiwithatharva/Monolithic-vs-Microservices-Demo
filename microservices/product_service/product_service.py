from flask import Flask, jsonify
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - [ProductSvc] %(message)s')

app = Flask(__name__)

# Add some dummy products
products = {
    "prod123": {"name": "Laptop", "price": 1200},
    "prod456": {"name": "Mouse", "price": 25},
    "prod789": {"name": "Keyboard", "price": 75}
}

@app.route('/product/<string:product_id>', methods=['GET'])
def get_product(product_id):
    product = products.get(product_id)
    if product:
        logging.info(f"Found product: {product_id}")
        return jsonify(product), 200
    else:
        logging.warning(f"Product not found: {product_id}")
        return jsonify({"error": "Product not found"}), 404

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({"status": "UP"}), 200

if __name__ == '__main__':
    logging.info("Starting Product Service Flask app (for local dev)")
    app.run(debug=True, host='0.0.0.0', port=5002) # Different port