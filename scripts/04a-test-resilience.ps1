# comparative-demo/04a-test-resilience.ps1
Clear-Host
Write-Host "--- Step 4a: Testing Resilience (Fault Isolation) ---" -ForegroundColor Yellow
Write-Host "This test demonstrates Kubernetes self-healing and how microservice failures are isolated."

# Prerequisites Check
Write-Host "`nPrerequisites:" -ForegroundColor Cyan
Write-Host " - Ensure the Frontend UI is open and configured (from script 03)."
Write-Host " - Ensure the `kubectl port-forward` commands for ALL backend services are running in separate terminals."
Read-Host -Prompt "Press Enter to continue if prerequisites are met"

# Test Microservice Failure
Write-Host "`n[1] Simulating Product Service Failure (Microservices)" -ForegroundColor Cyan

# Get a product service pod name
Write-Host "Finding a product-service pod to delete..."
$productPod = kubectl get pods -l app=product-service -o jsonpath='{.items[0].metadata.name}'
if (-not $productPod) {
    Write-Host "ERROR: No product-service pods found. Did deployment succeed?" -ForegroundColor Red
    exit 1
}
Write-Host "Will delete pod: $productPod" -ForegroundColor White

Read-Host -Prompt "Press Enter to DELETE the Product Service pod '$productPod'"
kubectl delete pod $productPod

Write-Host "`nObserve Kubernetes & Test UI:" -ForegroundColor Green
Write-Host " 1. Watch Kubernetes recreate the pod: In *another* terminal, run: kubectl get pods -l app=product-service -w"
Write-Host " 2. **QUICKLY** go to the UI:"
Write-Host "    a. Click 'Create Order' in the MICROSERVICES section -> Expect an ERROR (Order needs Product)."
Write-Host "    b. Click 'Create User' in the MICROSERVICES section -> Expect SUCCESS (User service is unaffected)."
Write-Host "This shows Kubernetes self-healing and microservice fault isolation."

Read-Host -Prompt "Press Enter after observing the microservice failure and recovery"


# Test Monolith Failure
Write-Host "`n[2] Simulating Monolith Failure" -ForegroundColor Cyan

# Get a monolith pod name
Write-Host "Finding a monolith pod to delete..."
$monolithPod = kubectl get pods -l app=monolith -o jsonpath='{.items[0].metadata.name}'
if (-not $monolithPod) {
    Write-Host "ERROR: No monolith pods found. Did deployment succeed? (Monolith deployment is optional in README)" -ForegroundColor Red
    Write-Host "If you skipped monolith deployment, you can skip this part."
    Read-Host -Prompt "Press Enter to continue anyway (or Ctrl+C to exit)"
    # If monolith wasn't deployed, we can just skip the rest of this section
    if (-not $monolithPod) { 
       Write-Host "Skipping monolith failure test as no pod was found." -ForegroundColor Yellow
    }
}

# Only proceed if monolith pod was found
if ($monolithPod) {
    Write-Host "Will delete pod: $monolithPod" -ForegroundColor White
    Read-Host -Prompt "Press Enter to DELETE the Monolith pod '$monolithPod'"
    kubectl delete pod $monolithPod

    Write-Host "`nObserve Kubernetes & Test UI:" -ForegroundColor Green
    Write-Host " 1. Watch Kubernetes recreate the pod: In *another* terminal, run: kubectl get pods -l app=monolith -w"
    Write-Host " 2. **QUICKLY** go to the UI:"
    Write-Host "    a. Click ANY button ('Create User', 'Get Product', 'Create Order') in the MONOLITH section -> Expect ALL to FAIL."
    Write-Host "This shows that a failure in one part of the monolith brings down *all* its functionality."

    Read-Host -Prompt "Press Enter after observing the monolith failure and recovery"
}


Write-Host "`n--- Resilience Test Complete ---" -ForegroundColor Yellow
Read-Host -Prompt "Press Enter to finish this script"