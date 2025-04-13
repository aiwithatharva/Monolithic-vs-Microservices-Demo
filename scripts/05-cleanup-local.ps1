# comparative-demo/05-cleanup-local.ps1
Clear-Host
Write-Host "--- Step 5: Cleanup (Local Images Mode) ---" -ForegroundColor Yellow

# Check if in correct directory
if (-not (Test-Path .\kubernetes -PathType Container)) {
    Write-Host "ERROR: Cannot find the 'kubernetes' directory." -ForegroundColor Red
    Write-Host "Please run this script from the root 'comparative-demo' project directory."
    exit 1
}

# 1. Stop Port Forwarding Reminder
Write-Host "[1] Stop Port Forwarding" -ForegroundColor Cyan
Write-Host "If you still have `kubectl port-forward` terminals open, please close them now (Ctrl+C)."
Read-Host -Prompt "Press Enter after closing port-forward terminals"

# 2. Delete Kubernetes Resources
Write-Host "`n[2] Deleting Kubernetes resources..." -ForegroundColor Cyan
Write-Host "(This will delete all Deployments, Services, Pods, and HPA created by the .yaml files)"

Push-Location .\kubernetes
if (-not $?) { Write-Host "ERROR: Failed to change directory to .\kubernetes" -ForegroundColor Red; exit 1; }

kubectl delete -f .
Write-Host "Deletion commands sent. Waiting a moment for resources to terminate..."
Start-Sleep -Seconds 10 # Give K8s some time

Pop-Location

# 3. Verify Deletion
Write-Host "`n[3] Verifying resource deletion..." -ForegroundColor Cyan
kubectl get deployments,services,pods,hpa
Write-Host "The command above should show 'No resources found'. If items are still 'Terminating', wait a bit longer and check again manually."

# 4. Optional: Disable Kubernetes / Remove Images
Write-Host "`n[4] Further Cleanup (Manual Steps)" -ForegroundColor Cyan
Write-Host " - To stop the Kubernetes cluster: Open Docker Desktop Settings > Kubernetes > Uncheck 'Enable Kubernetes' > Apply & Restart."
Write-Host " - OR simply Quit Docker Desktop."
Write-Host " - Optional: Remove local Docker images:"
Write-Host "   docker rmi monolith-app:v1 user-service:v1 product-service:v1 order-service:v1 frontend-app:v1"


Write-Host "`n--- Cleanup Complete ---" -ForegroundColor Yellow
Read-Host -Prompt "Press Enter to finish this script"