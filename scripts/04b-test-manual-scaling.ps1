# comparative-demo/04b-test-manual-scaling.ps1
Clear-Host
Write-Host "--- Step 4b: Testing Scalability (Manual Scaling) ---" -ForegroundColor Yellow
Write-Host "This test demonstrates manually scaling deployments up and down."

# Prerequisites Check
Write-Host "`nPrerequisites:" -ForegroundColor Cyan
Write-Host " - Ensure the Frontend UI is open and configured (from script 03)."
Write-Host " - Ensure the `kubectl port-forward` commands for relevant services (Order, Monolith) are running."
Read-Host -Prompt "Press Enter to continue if prerequisites are met"


# Scale Up
Write-Host "`n[1] Scaling UP Order Service and Monolith to 3 Replicas" -ForegroundColor Cyan

Write-Host "Scaling Order Service (Microservice)..."
kubectl scale deployment order-service-deployment --replicas=3
Read-Host -Prompt "Press Enter to check Order Service pods (should see 3 starting/running)"
kubectl get pods -l app=order-service -o wide

Write-Host "`nScaling Monolith..."
kubectl scale deployment monolith-deployment --replicas=3
Read-Host -Prompt "Press Enter to check Monolith pods (should see 3 starting/running)"
kubectl get pods -l app=monolith -o wide

Write-Host "`nObserve and Test:" -ForegroundColor Green
Write-Host " - Use the 'Create Order' buttons in both UI sections."
Write-Host " - Requests to the scaled services are automatically load-balanced across the replicas (even via port-forward)."
Write-Host " - Note: Scaling the Order service *only* scaled order capacity. Scaling the monolith scaled *everything*."

Read-Host -Prompt "Press Enter after observing the scaled-up state"


# Scale Down
Write-Host "`n[2] Scaling DOWN Order Service and Monolith back to 1 Replica" -ForegroundColor Cyan

Write-Host "Scaling down Order Service..."
kubectl scale deployment order-service-deployment --replicas=1
Read-Host -Prompt "Press Enter to check Order Service pods (should see pods terminating until 1 remains)"
kubectl get pods -l app=order-service -o wide

Write-Host "`nScaling down Monolith..."
kubectl scale deployment monolith-deployment --replicas=1
Read-Host -Prompt "Press Enter to check Monolith pods (should see pods terminating until 1 remains)"
kubectl get pods -l app=monolith -o wide

Write-Host "`n--- Manual Scaling Test Complete ---" -ForegroundColor Yellow
Read-Host -Prompt "Press Enter to finish this script"