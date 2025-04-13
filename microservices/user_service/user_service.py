from flask import Flask, request, jsonify
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - [UserSvc] %(message)s')

app = Flask(__name__)

users = {} # user_id -> username
user_counter = 0

@app.route('/user', methods=['POST'])
def create_user():
    global user_counter
    data = request.get_json()
    if not data or 'username' not in data:
        logging.warning("Create user failed: Missing username")
        return jsonify({"error": "Username is required"}), 400
    user_counter += 1
    user_id = f"user{user_counter}"
    users[user_id] = data['username']
    logging.info(f"Created user: {user_id} -> {data['username']}")
    logging.info(f"Current Users: {users}")
    return jsonify({"user_id": user_id, "username": data['username']}), 201

@app.route('/user/<string:user_id>', methods=['GET'])
def get_user(user_id):
    if user_id in users:
        logging.info(f"Found user: {user_id}")
        return jsonify({"user_id": user_id, "username": users[user_id]}), 200
    else:
        logging.warning(f"User not found: {user_id}")
        return jsonify({"error": "User not found"}), 404

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({"status": "UP"}), 200

if __name__ == '__main__':
    logging.info("Starting User Service Flask app (for local dev)")
    app.run(debug=True, host='0.0.0.0', port=5001) # Different port