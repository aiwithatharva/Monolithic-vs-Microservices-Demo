# Monolith vs Microservices - Kubernetes Demo (Docker Desktop Kubernetes on Windows)

This project provides a very simplified implementation of the same basic functionality (User creation, Product lookup, Order creation) using both a monolithic architecture and a microservices architecture, along with a basic web frontend.

It demonstrates how to deploy and manage these applications using **Kubernetes integrated with Docker Desktop on Windows**, highlighting differences in deployment, fault tolerance, manual scaling, and automatic scaling (HPA).

**Technology:** Python 3.9+, Flask, Gunicorn, Requests, Docker, Kubernetes (Docker Desktop), kubectl, Nginx (for frontend), Windows PowerShell

## Project Structure

comparative-demo/
├── frontend/            # Simple HTML/JS UI
│   ├── index.html
│   ├── script.js
│   └── Dockerfile       # Uses Nginx
├── monolith/            # Monolith Flask App
│   ├── monolith_app.py
│   ├── requirements.txt
│   └── Dockerfile
├── microservices/       # Microservices Flask Apps
│   ├── user_service/
│   ├── product_service/
│   └── order_service/
├── kubernetes/          # Kubernetes Manifests
│   ├── 00-monolith.yaml
│   ├── 01-user-service.yaml
│   ├── 02-product-service.yaml
│   ├── 03-order-service.yaml  # Includes Resource Requests for HPA
│   ├── 04-order-service-hpa.yaml # Autoscaler definition
│   └── 05-frontend.yaml
└── README.md            # This file


## Setup

1.  **Install Docker Desktop for Windows:** Ensure Docker Desktop is installed and running. The WSL 2 backend is recommended. ([Docker Docs](https://docs.docker.com/desktop/install/windows-install/)).
2.  **Enable Kubernetes in Docker Desktop:**
    *   Open Docker Desktop **Settings**.
    *   Go to the **Kubernetes** section.
    *   Check the **"Enable Kubernetes"** box.
    *   Click **"Apply & Restart"**.
    *   Wait for the Kubernetes cluster to start (the icon in the bottom-left of Docker Desktop should turn green and say "Kubernetes running"). This can take a few minutes the first time.
3.  **Install kubectl:** The Kubernetes command-line tool. Follow instructions [here](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/). Verify by opening PowerShell and running `kubectl version --client`.
4.  **Set kubectl Context:** Docker Desktop should automatically set the context. Verify it's targeting the Docker Desktop cluster:
    
    ```powershell
    kubectl config current-context 
    # Should output: docker-desktop
    # If not, run: kubectl config use-context docker-desktop
    ```
5.  **Verify Metrics Server:** The metrics-server is required for HPA and is usually included with Docker Desktop Kubernetes. Verify it's running and collecting metrics (this might take a minute or two after Kubernetes starts):
    
    ```powershell
    kubectl top nodes
    kubectl top pods -n kube-system 
    # Look for pods starting with 'metrics-server'
    ```
    *   *Troubleshooting:* If `kubectl top nodes` gives an error about metrics not being available, try resetting the Kubernetes cluster in Docker Desktop Settings > Kubernetes > Reset Kubernetes Cluster, or restarting Docker Desktop. Wait a few minutes after it restarts.
6.  **Docker Hub Account:** Create a free account at [Docker Hub](https://hub.docker.com/). **You MUST replace `atharva621`** in the commands below and in all `.yaml` files with *your* Docker Hub username.
7.  **Clone Repository:** Get the code onto your machine.
    
    ```powershell
    # Example using git:
    # git clone <your-repo-url>
    # cd comparative-demo
    ```


## Step 1: Build and Push Docker Images

**IMPORTANT:** Replace `atharva621` with your actual Docker Hub username everywhere it appears below and in the `.yaml` files (specifically the `image:` lines).

1.  Navigate to the project's root directory (`comparative-demo`) in PowerShell.
2.  Log in to Docker Hub:
    
    ```powershell
    docker login
    ```
3.  Build the images:
    
    ```powershell
    # Monolith
    docker build -t atharva621/monolith-app:v1 .\monolith

    # Microservices
    docker build -t atharva621/user-service:v1 .\microservices\user_service
    docker build -t atharva621/product-service:v1 .\microservices\product_service
    docker build -t atharva621/order-service:v1 .\microservices\order_service

    # Frontend
    docker build -t atharva621/frontend-app:v1 .\frontend
    ```
4.  Push the images to Docker Hub:
    
    ```powershell
    docker push atharva621/monolith-app:v1
    docker push atharva621/user-service:v1
    docker push atharva621/product-service:v1
    docker push atharva621/order-service:v1
    docker push atharva621/frontend-app:v1
    ```

**Alternative (Local Images without Docker Hub):**
*   Because Docker Desktop Kubernetes shares the same Docker daemon, you can often use locally built images directly.
*   **Build Locally:** Use `docker build -t monolith-app:v1 .\monolith` etc. (omit the username prefix).
*   **YAML Changes:** In the `.yaml` files, change `image:` to the local name (e.g., `image: monolith-app:v1`). Crucially, you *must* also add `imagePullPolicy: Never` to each Deployment spec (`spec.template.spec.containers.[].imagePullPolicy`). This tells Kubernetes *not* to try pulling from a remote registry. If you omit `imagePullPolicy`, the default is `IfNotPresent`, which might still try to pull if the tag (`:v1`) hasn't been seen before by K8s.
*   *Recommendation:* Pushing to Docker Hub (as described above) is generally more robust for tutorials and avoids potential confusion with image pull policies.

## Step 2: Deploy to Kubernetes

1.  Ensure `kubectl` context is `docker-desktop`: `kubectl config current-context`
2.  Navigate to the `kubernetes` directory: `cd comparative-demo\kubernetes`
3.  Apply all the manifests:
    
    ```powershell
    # Apply backend and frontend manifests
    kubectl apply -f .\00-monolith.yaml         # Optional Monolith
    kubectl apply -f .\01-user-service.yaml
    kubectl apply -f .\02-product-service.yaml
    kubectl apply -f .\03-order-service.yaml    # Has resource requests needed by HPA
    kubectl apply -f .\05-frontend.yaml

    # Apply the Autoscaler for the order service
    kubectl apply -f .\04-order-service-hpa.yaml

    # Alternatively, apply all YAML files in the directory: 
    # kubectl apply -f . 
    ```
4.  Check deployment status (Wait for Pods to be Running and Services to get External IPs):
    
    ```powershell
    kubectl get deployments
    kubectl get pods -o wide
    kubectl get services 
    # Wait for EXTERNAL-IP to show 'localhost' for LoadBalancer services
    kubectl get hpa # Check the HorizontalPodAutoscaler
    ```
    *   Troubleshooting: If `ImagePullBackOff`, check your image names/tags in the YAML files match what you pushed (including your Docker Hub username) and that you pushed successfully. Check `docker images` locally. If `Pending`, check `kubectl describe pod <pod-name>`. HPA target might show `<unknown>` initially until metrics are available (`kubectl top pods`). Services of type `LoadBalancer` might show `<pending>` under `EXTERNAL-IP` for a short time before getting assigned `localhost`.

## Step 3: Accessing the Frontend UI & Configuring Backend URLs

Docker Desktop Kubernetes exposes services (like `LoadBalancer` or `NodePort`) directly on your `localhost`.

1.  **Access the Frontend UI:**
    *   Find the port for the frontend service:
        
        ```powershell
        kubectl get service frontend-service
        ```
    *   Look at the `PORT(S)` column. It will show something like `80:3XXXX/TCP`. The first number (`80`) is the port the service listens on *inside* the cluster. The second number (`3XXXX`) is the `NodePort` assigned by Kubernetes, which Docker Desktop maps to your `localhost`.
    *   **If the service TYPE is `LoadBalancer`**: The `EXTERNAL-IP` should become `localhost`. Access the UI using the port listed *before* the colon in the `PORT(S)` column (usually port 80 for web servers). URL: `http://localhost:80` (or just `http://localhost`).
    *   **If the service TYPE is `NodePort` (as defined in `05-frontend.yaml`)**: Use the *second* port number (the NodePort, `3XXXX` range). URL: `http://localhost:<NodePort>` (e.g., `http://localhost:31234`). The provided `05-frontend.yaml` uses `LoadBalancer`, so `http://localhost` should work.
    *   Open the determined URL in your web browser.
2.  **Configure Backend URLs in the UI:**
    *   The UI needs the URLs for the backend APIs (Monolith, User, Product, Order).
    *   For **each** backend service (`monolith-service`, `user-service`, `product-service`, `order-service`):
        *   Get its port information:
            
            ```powershell
            kubectl get service <service-name> 
            # e.g., kubectl get service monolith-service
            ```
        *   Determine the access URL similar to step 1:
            *   If `TYPE` is `LoadBalancer`, use `http://localhost:<port-before-colon>`. The example YAMLs use `ClusterIP` for backends, which aren't directly accessible from outside the cluster *unless* you use port-forwarding or change the service type. **Let's assume for simplicity the YAMLs were changed to use `LoadBalancer` or `NodePort` for backend services too for this UI interaction.** *If they remain ClusterIP*, you'd need `kubectl port-forward service/<service-name> <local-port>:<service-port>` for each and use `http://localhost:<local-port>`.
            *   **Let's modify the instructions assuming the services are accessible externally (e.g., `LoadBalancer` or `NodePort`):** Find the correct `http://localhost:<port>` for each service using `kubectl get service <service-name>`.
        *   **Paste** the full `http://localhost:<port>` URL into the corresponding input field in the Frontend UI's "Configuration" section.
    *   After pasting all necessary URLs, click the **"Update URLs"** button *in the UI*.

    ***Self-Correction/Clarification:*** The original YAML files likely use `ClusterIP` for backend services, meaning they *aren't* directly accessible via `localhost`. The simplest way to make them accessible for this demo *without* changing YAMLs is `kubectl port-forward`.

    **Revised Step 3.2 (Using `kubectl port-forward`):**

    1.  **Configure Backend URLs in the UI:**
        *   The UI needs URLs accessible from your browser. We'll use `kubectl port-forward` to create tunnels from your `localhost` to the internal cluster services.
        *   For **each** backend service (`monolith-service`, `user-service`, `product-service`, `order-service`):
            *   Open a **new, separate PowerShell terminal** for each service you want to forward.
            *   Find the *internal* port the service listens on (the port *after* the colon in the service definition, usually 5000, 5001, etc. in the Flask apps):
                ```powershell
                kubectl get service <service-name> -o jsonpath='{.spec.ports[0].port}'
                # e.g., for monolith-service, it might output 5000
                ```
            *   Run `kubectl port-forward`: Choose a unique local port (e.g., 8080, 8081, 8082, 8083) for each service.
                ```powershell
                # Terminal 1: Monolith
                kubectl port-forward service/monolith-service 8080:5000 
                
                # Terminal 2: User Service
                kubectl port-forward service/user-service 8081:5001 

                # Terminal 3: Product Service
                kubectl port-forward service/product-service 8082:5002

                # Terminal 4: Order Service
                kubectl port-forward service/order-service 8083:5003 
                ```
                *(Adjust the second port number, e.g., `:5000`, if your Flask apps use different ports)*
            *   **Keep these terminals running!** The port forward stops when you close the terminal or press Ctrl+C.
            *   The URL to use in the UI for each service is now `http://localhost:<local-port>` (e.g., `http://localhost:8080` for Monolith, `http://localhost:8081` for User).
            *   **Paste** these `localhost` URLs into the corresponding input fields in the Frontend UI's "Configuration" section.
        *   After pasting all necessary URLs, click the **"Update URLs"** button *in the UI*.

## Step 4: Testing Scenarios (Using the Frontend UI)

**Important:** Ensure you completed Step 3 (UI access and backend URL configuration/port-forwarding) and the necessary `kubectl port-forward` commands are running if you used that method.

**Scenario 1: Basic Functionality Check**

1.  Use the buttons and input fields in the **Monolith** section of the UI to:
    *   Create a user. Note the `user_id` displayed in the response area.
    *   Get product details.
    *   Use the created `user_id` to create an order. Observe responses.
2.  Use the buttons and input fields in the **Microservices** section of the UI to perform the same actions. Observe responses and note how interactions involve different backend services (accessed via their forwarded `localhost` URLs).

**Scenario 2: Resilience Test (Kubernetes Self-Healing & Fault Isolation)**

1.  Get the name of a **Product Service** pod:
    
    ```powershell
    kubectl get pods -l app=product-service -o name
    # Copy the pod name, e.g., pod/product-service-deployment-xxxx-yyyy
    ```
2.  Delete the pod: `kubectl delete <copied-pod-name>` (e.g., `kubectl delete pod/product-service-deployment-xxxx-yyyy`)
3.  **Observe Kubernetes:** In another terminal, watch `kubectl get pods -w` to see the pod terminate and a new one start automatically (Self-Healing).
4.  **Test via UI (While pod is restarting):**
    *   **Fault:** Quickly click "Create Order" in the **Microservices** section of the UI. Observe the error response in the UI (likely 503/504 from the Order Service, or maybe a connection refused error from the port-forward if the new pod isn't ready).
    *   **Isolation:** Immediately click "Create User" in the **Microservices** section. This should succeed (assuming its port-forward is running), showing the new user in the response area. This demonstrates that the Product service failure didn't stop the User service.
5.  **Contrast:** Delete the monolith pod (`kubectl delete pod/<monolith-pod-name>`). Try clicking *any* button in the **Monolith** section of the UI while it restarts. All actions should fail.

**Scenario 3: Scalability Test (Manual Scaling Observation)**

*   Use `kubectl scale` commands to manually adjust replica counts:
    
    ```powershell
    # Scale up Order Service (Microservice)
    kubectl scale deployment order-service-deployment --replicas=3
    kubectl get pods -l app=order-service # Observe 3 pods

    # Scale up Monolith
    kubectl scale deployment monolith-deployment --replicas=3
    kubectl get pods -l app=monolith # Observe 3 pods
    ```
*   **Use the UI:** After scaling, use the "Create Order" buttons in both sections. Note that your `kubectl port-forward service/order-service ...` command will automatically load balance across the new replicas.
*   **Explain:** Emphasize that scaling the microservice only added resources for order processing, while scaling the monolith added resources for *everything* (user, product, order), highlighting the potential resource efficiency difference.
*   **Scale back down:**
    
    ```powershell
    kubectl scale deployment order-service-deployment --replicas=1
    kubectl scale deployment monolith-deployment --replicas=1
    ```

**Scenario 4: Autoscaling Demo (HPA)**

1.  **Verify Prerequisites:**
    *   Ensure HPA is running: `kubectl get hpa order-service-hpa`. The TARGETS column should show current CPU % vs target (e.g., `2%/30%`). If `<unknown>`, wait for metrics-server data (`kubectl top pods -l app=order-service`).
    *   Ensure Order Service is accessible (e.g., `kubectl port-forward service/order-service ...` is running) and its URL is configured in the UI.
2.  **Start Load:** In the Frontend UI, go to the "Autoscaling Demo" section and click **"Start Load"**. Observe the status message change.
3.  **Observe Kubernetes:**
    *   Watch HPA: `kubectl get hpa order-service-hpa -w`. See TARGETS CPU % increase. When it exceeds 30%, REPLICAS count should climb from 1 towards 4 (takes a minute or two per step).
    *   Watch Pods: `kubectl get pods -l app=order-service -w`. See new pods (Pending -> ContainerCreating -> Running).
4.  **Stop Load:** Click **"Stop Load"** in the UI.
5.  **Observe Scale Down:** Continue watching HPA and Pods. CPU % will drop. After a stabilization period (default ~5 mins), REPLICAS count will decrease back to 1, and extra pods will terminate.
6.  **Explain:** This shows Kubernetes automatically reacting to load by scaling the *specific* microservice based on observed CPU metrics, then scaling back down when load subsides.

## Step 5: Cleanup

1.  **Stop Load Generator:** Ensure the load generator in the UI is stopped.
2.  **Close Terminals:** Close all the PowerShell terminals running `kubectl port-forward ...`.
3.  **Delete Kubernetes Resources:**
    
    ```powershell
    # Navigate back to comparative-demo\kubernetes if needed
    kubectl delete -f .
    # Verify deletion:
    kubectl get deployments,pods,services,hpa # Should show 'No resources found'
    ```
4.  **Disable/Stop Kubernetes:**
    *   Go to Docker Desktop **Settings > Kubernetes**.
    *   Uncheck **"Enable Kubernetes"** and click **"Apply & Restart"**.
    *   Alternatively, simply **quit Docker Desktop**.
5.  **(Optional) Reset Kubernetes Cluster:** If you want to ensure a completely clean state for next time without disabling/re-enabling, go to Docker Desktop Settings > Kubernetes > **Reset Kubernetes Cluster**. Use with caution, this deletes all deployed resources.
6.  **(Optional) Logout from Docker Hub:** `docker logout`
7.  **(Optional) Remove Docker Images:** `docker rmi atharva621/image:tag ...` (list all the images built).#   M o n o l i t h i c - v s - M i c r o s e r v i c e s - D e m o  
 