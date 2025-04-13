# comparative-demo/00-verify-setup-local-no-hpa.ps1
Clear-Host
Write-Host "--- Step 0: Verifying Setup (Local Images Mode) ---" -ForegroundColor Yellow
Write-Host "NOTE: This version acknowledges potential metrics-server issues and allows"
Write-Host "      proceeding without functional HPA (Autoscaling Demo)." -ForegroundColor Cyan

# 1. Check Docker
Write-Host "`n[1] Checking Docker Installation & Status..."
docker --version
if ($?) {
    Write-Host "Docker command found." -ForegroundColor Green
    docker info > $null # Check if daemon is running
    if ($?) {
        Write-Host "Docker Desktop appears to be running." -ForegroundColor Green
    } else {
        Write-Host "ERROR: Docker command works, but the Docker daemon doesn't seem responsive." -ForegroundColor Red
        Write-Host "Please ensure Docker Desktop is installed AND running."
        exit 1
    }
} else {
    Write-Host "ERROR: 'docker' command not found." -ForegroundColor Red
    Write-Host "Please install Docker Desktop for Windows: https://docs.docker.com/desktop/install/windows-install/"
    exit 1
}

# 2. Check kubectl
Write-Host "`n[2] Checking kubectl Installation..."
kubectl version --client --output=yaml
if ($?) {
    Write-Host "kubectl command found." -ForegroundColor Green
} else {
    Write-Host "ERROR: 'kubectl' command not found." -ForegroundColor Red
    Write-Host "Please install kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/"
    exit 1
}

# 3. Check Kubernetes Cluster (Docker Desktop)
Write-Host "`n[3] Checking Kubernetes Context and Cluster Status..."
Write-Host "   (This requires Kubernetes to be enabled in Docker Desktop Settings)"
$currentContext = kubectl config current-context
if ($currentContext -eq "docker-desktop") {
    Write-Host "kubectl context is correctly set to 'docker-desktop'." -ForegroundColor Green
} else {
    Write-Host "WARNING: kubectl context is '$currentContext'. It should be 'docker-desktop'." -ForegroundColor Yellow
    Write-Host "Attempting to set context..."
    kubectl config use-context docker-desktop
    if ($?) {
         Write-Host "Context set to 'docker-desktop'." -ForegroundColor Green
    } else {
         Write-Host "ERROR: Failed to set context to 'docker-desktop'. Is Kubernetes enabled in Docker Desktop?" -ForegroundColor Red
         exit 1
    }
}

# Try a cluster command
kubectl cluster-info > $null
if ($?) {
    Write-Host "Successfully connected to the Kubernetes cluster." -ForegroundColor Green
} else {
    Write-Host "ERROR: Could not connect to the Kubernetes cluster via 'kubectl cluster-info'." -ForegroundColor Red
    Write-Host "Please ensure Kubernetes is enabled AND running in Docker Desktop Settings (wait for green status)."
    exit 1
}




Write-Host "`n--- Verification Complete ---" -ForegroundColor Yellow
Write-Host "Setup verified for running the demo."

Read-Host -Prompt "Press Enter to finish this script"



# comparative-demo/01-build-images-local.ps1
Clear-Host
Write-Host "--- Step 1: Build Docker Images Locally ---" -ForegroundColor Yellow
Write-Host "(Skipping Docker Hub push)"

# Define images and build context paths
$images = @{
    "monolith-app"      = ".\monolith"
    "user-service"      = ".\microservices\user_service"
    "product-service"   = ".\microservices\product_service"
    "order-service"     = ".\microservices\order_service"
    "frontend-app"      = ".\frontend"
}
$tag = "v1"

# Build images locally
Write-Host "`n[1] Building Docker Images..." -ForegroundColor Cyan
foreach ($imageName in $images.Keys) {
    $contextPath = $images[$imageName]
    $fullImageName = "$imageName`:$tag" # Use simple name:tag format
    Write-Host "Building $fullImageName from $contextPath ..."
    docker build -t $fullImageName $contextPath
    if (-not $?) {
        Write-Host "ERROR: Failed to build $fullImageName." -ForegroundColor Red
        exit 1
    }
}
Write-Host "All images built successfully locally." -ForegroundColor Green


Write-Host "`n--- Local Build Complete ---" -ForegroundColor Yellow




# comparative-demo/02-deploy-kubernetes-local.ps1
Clear-Host
Write-Host "--- Step 2: Deploy to Kubernetes (Local Images Mode) ---" -ForegroundColor Yellow

# Check if in correct directory
if (-not (Test-Path .\kubernetes -PathType Container)) {
    Write-Host "ERROR: Cannot find the 'kubernetes' directory." -ForegroundColor Red
    Write-Host "Please run this script from the root 'comparative-demo' project directory."
    exit 1
}

# Check kubectl context again
Write-Host "`n[1] Verifying kubectl context..."
$currentContext = kubectl config current-context
if ($currentContext -ne "docker-desktop") {
     Write-Host "ERROR: kubectl context is '$currentContext'. It MUST be 'docker-desktop'." -ForegroundColor Red
     Write-Host "Run 'kubectl config use-context docker-desktop' and restart this script."
     exit 1
}
Write-Host "kubectl context is 'docker-desktop'." -ForegroundColor Green


# Apply manifests
Write-Host "`n[2] Applying Kubernetes manifests from the 'kubernetes' directory..." -ForegroundColor Cyan

Read-Host -Prompt "Press Enter to apply manifests"

# Navigate and apply
Push-Location .\kubernetes
if (-not $?) { Write-Host "ERROR: Failed to change directory to .\kubernetes" -ForegroundColor Red; exit 1; }

kubectl apply -f .
if (-not $?) {
    Write-Host "ERROR: 'kubectl apply -f .' failed. Check the output above for errors." -ForegroundColor Red
    Write-Host "Common issues (local mode): YAML files not edited correctly (missing 'imagePullPolicy: Never' or wrong image name)."
    Pop-Location
    exit 1
}
Write-Host "Manifests applied." -ForegroundColor Green
Pop-Location


# Check deployment status
Write-Host "`n[3] Checking deployment status (wait for Pods to be 'Running')..." -ForegroundColor Cyan
Write-Host "   (If you see 'ImagePullBackOff' or 'ErrImageNeverPull', it means the YAML edits were incorrect"
Write-Host "    or the image wasn't built locally in Step 1. Check 'kubectl describe pod <pod-name>' for details.)"
Read-Host -Prompt "Press Enter to view Deployments"
kubectl get deployments

Read-Host -Prompt "Press Enter to view Pods (check STATUS and READY columns)"
kubectl get pods -o wide

Read-Host -Prompt "Press Enter to view Services (check TYPE and EXTERNAL-IP/PORT(S))"
kubectl get services
Write-Host "   ('LoadBalancer' services might show <pending> for EXTERNAL-IP briefly before becoming 'localhost')"


Write-Host "`n--- Deployment Complete ---" -ForegroundColor Yellow
Write-Host "If all pods are 'Running' and services look okay, proceed to the next script (03)."
Write-Host "If you see errors (ImagePullBackOff/ErrImageNeverPull), double-check your YAML modifications and that images were built locally."
Read-Host -Prompt "Press Enter to finish this script"



# comparative-demo/03-access-and-configure.ps1
Clear-Host
Write-Host "--- Step 3: Accessing Frontend UI & Configuring Backend URLs ---" -ForegroundColor Yellow

Write-Host "`n[1] Finding Frontend UI Access URL..." -ForegroundColor Cyan

# Get Frontend Service Info
Write-Host "Getting details for 'frontend-service'..."
kubectl get service frontend-service

Write-Host "`nInterpret the Frontend Service Output:" -ForegroundColor Green
Write-Host " - If TYPE is LoadBalancer: The EXTERNAL-IP should be 'localhost'. Access the UI via http://localhost:<PORT>"
Write-Host "   (The <PORT> is the first number listed under PORT(S), usually 80 for web apps. So likely just http://localhost)"
Write-Host " - If TYPE is NodePort: The EXTERNAL-IP might be <none>. Access the UI via http://localhost:<NODEPORT>"
Write-Host "   (The <NODEPORT> is the second number listed under PORT(S), typically in the 30000-32767 range, e.g., http://localhost:31234)"

$frontendUrl = Read-Host -Prompt "Based on the output above, enter the URL to access the Frontend UI (e.g., http://localhost or http://localhost:3XXXX)"
Write-Host "Okay, try opening '$frontendUrl' in your web browser."
Read-Host -Prompt "Press Enter after you have the Frontend UI open in your browser"

Write-Host "`n[2] Configuring Backend URLs using 'kubectl port-forward'" -ForegroundColor Cyan
Write-Host "The backend services (monolith, user, product, order) use 'ClusterIP' by default."
Write-Host "This means they are only reachable *inside* the Kubernetes cluster."
Write-Host "To access them from your browser (via the Frontend UI), we need to forward local ports to the cluster services."
Write-Host "`nIMPORTANT: You need to open **SEPARATE** PowerShell terminals for EACH `kubectl port-forward` command below."
Write-Host "These terminals MUST **REMAIN OPEN** while you are testing the application." -ForegroundColor Yellow

# Define services and their typical internal ports (adjust if your apps use different ones)
$backendServices = @{
    "monolith-service" = 5000 # Assumes monolith_app.py runs on port 5000
    "user-service"     = 5001 # Assumes user_service runs on port 5001
    "product-service"  = 5002 # Assumes product_service runs on port 5002
    "order-service"    = 5003 # Assumes order_service runs on port 5003
}
$localPortStart = 8080

# Generate and display port-forward commands
Write-Host "`nOpen new PowerShell terminals and run these commands (one per terminal):" -ForegroundColor Green
$serviceUrls = @{}
$currentLocalPort = $localPortStart
foreach ($serviceName in $backendServices.Keys) {
    $servicePort = $backendServices[$serviceName]
    $command = "kubectl port-forward service/$serviceName $currentLocalPort`:$servicePort"
    $url = "http://localhost:$currentLocalPort"
    Write-Host "`nTerminal for '$serviceName':"
    Write-Host "  Run: $command" -ForegroundColor White
    Write-Host "  UI URL: $url" -ForegroundColor White
    $serviceUrls[$serviceName] = $url
    $currentLocalPort++
}

Write-Host "`n[3] Update Frontend UI Configuration" -ForegroundColor Cyan
Write-Host "Once the port-forward commands are running in their separate terminals:"
Write-Host " - Go back to the Frontend UI in your browser."
Write-Host " - In the 'Configuration' section, paste the following URLs:"
Write-Host "   - Monolith API URL: $($serviceUrls['monolith-service'])"
Write-Host "   - User Service API URL: $($serviceUrls['user-service'])"
Write-Host "   - Product Service API URL: $($serviceUrls['product-service'])"
Write-Host "   - Order Service API URL: $($serviceUrls['order-service'])"
Write-Host " - Click the 'Update URLs' button *in the UI*."

Write-Host "`n--- Access and Configuration Setup ---" -ForegroundColor Yellow
Write-Host "Ensure:"
Write-Host "  1. The Frontend UI is open."
Write-Host "  2. ALL `kubectl port-forward` commands are running in their own terminals."
Write-Host "  3. The URLs have been pasted into the UI and 'Update URLs' was clicked."
Read-Host -Prompt "Press Enter when you are ready to proceed to testing scripts (04a, 04b, 04c)"