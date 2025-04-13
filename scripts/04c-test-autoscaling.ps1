# comparative-demo/04d-autoscale-listener.ps1
# (Listens for Frontend Commands via HTTP to Simulate Autoscaling - CORRECTED RESPONSE WRITING)
Clear-Host
Write-Host "--- Step 4d: AUTOSCALING SIMULATOR (HTTP Listener) ---" -ForegroundColor Yellow
Write-Host "This script listens for commands from the Frontend UI via HTTP"
Write-Host "to automatically scale the 'order-service-deployment'."
Write-Host "Ensure the Frontend JavaScript is updated to send requests to this script." -ForegroundColor Cyan
Write-Host "------------------------------------------------------------------------"

# --- Configuration ---
$deploymentName = "order-service-deployment"
$minReplicas = 1         # Replicas when idle or load stopped
$lowReplicas = 2         # Target replicas for "Low Load"
$mediumReplicas = 3      # Target replicas for "Medium Load"
$highReplicas = 4        # Target replicas for "High Load"
$listenerPort = 9999     # Port for the script to listen on
$listenerUriPrefix = "http://localhost:$listenerPort/notify/" # URI to listen on (trailing slash is important)

# Shortened delay for demo purposes
$scaleDownDelaySeconds = 10

# State Variables
$global:currentLoadLevel = 'none' # 'none', 'low', 'medium', 'high'
$global:isLoadRunning = $false
$global:scaleDownJob = $null # To hold the background job for delayed scale-down
# -------------------

# Function to check deployment existence
function Test-DeploymentExists {
    param($name)
    $result = kubectl get deployment $name -n default -o jsonpath='{.metadata.name}' --ignore-not-found=true 2>$null
    return ($result -ne $null -and $result -ne "")
}

# Function to handle scaling
function Set-DeploymentReplicas {
    param(
        [Parameter(Mandatory=$true)]
        [int]$replicas,
        [string]$reason # Optional reason for logging
    )
    Write-Host "$(Get-Date -Format 'HH:mm:ss') - Scaling '$deploymentName' to $replicas replicas. Reason: $reason" -ForegroundColor Green
    try {
        kubectl scale deployment $deploymentName --replicas=$replicas | Out-Null # Suppress kubectl output unless error
        Write-Host "$(Get-Date -Format 'HH:mm:ss') - Scale command sent successfully."
    } catch {
        Write-Warning "$(Get-Date -Format 'HH:mm:ss') - Failed to scale deployment '$deploymentName' to $replicas replicas."
        Write-Warning $_.Exception.Message
    }
}

# Function to cancel any pending scale-down job
function Cancel-PendingScaleDown {
    if ($global:scaleDownJob -ne $null -and $global:scaleDownJob.State -eq 'Running') {
        Write-Host "$(Get-Date -Format 'HH:mm:ss') - Cancelling pending scale-down job (ID: $($global:scaleDownJob.Id))..." -ForegroundColor Yellow
        Stop-Job $global:scaleDownJob # Attempt graceful stop first
        Start-Sleep -Milliseconds 200
        Remove-Job $global:scaleDownJob -Force
        $global:scaleDownJob = $null
         Write-Host "$(Get-Date -Format 'HH:mm:ss') - Pending scale-down job cancelled."
    } elseif ($global:scaleDownJob -ne $null) {
        # If job exists but isn't running (completed, failed, etc.), just remove it
        Remove-Job $global:scaleDownJob -Force
        $global:scaleDownJob = $null
    }
}

# *** HELPER FUNCTION TO WRITE HTTP RESPONSE ***
function Write-HttpResponse {
    param(
        [Parameter(Mandatory=$true)]
        [System.Net.HttpListenerResponse]$ResponseObject,
        [Parameter(Mandatory=$true)]
        [string]$Content,
        [System.Text.Encoding]$Encoding = [System.Text.Encoding]::UTF8
    )
    try {
        $buffer = $Encoding.GetBytes($Content)
        # Set content type and length for good practice
        $ResponseObject.ContentType = "text/plain; charset=utf-8" # Indicate plain text UTF8
        $ResponseObject.ContentLength64 = $buffer.Length
        $ResponseObject.OutputStream.Write($buffer, 0, $buffer.Length)
    } catch {
         Write-Warning "Failed to write content to HTTP response: $($_.Exception.Message)"
         # Don't try to write again here, just log the warning
    }
    # Closing the response stream happens *after* this function returns, in the main loop.
}


# --- Prerequisites ---
Write-Host "`n[1] Checking Prerequisites..." -ForegroundColor Cyan
Write-Host "   - Checking if deployment '$deploymentName' exists..."
if (-not (Test-DeploymentExists -name $deploymentName)) {
     Write-Host "ERROR: Deployment '$deploymentName' not found. Run '02-deploy-kubernetes-local.ps1' first." -ForegroundColor Red
     exit 1
}
Write-Host "   - Deployment '$deploymentName' found." -ForegroundColor Green
Write-Host "   - Checking kubectl access..."
kubectl version --client | Out-Null
if ($LASTEXITCODE -ne 0) {
     Write-Host "ERROR: kubectl command failed. Is it installed and in your PATH?" -ForegroundColor Red
     exit 1
}
Write-Host "   - kubectl access verified."

# --- Initialization ---
Write-Host "`n[2] Initializing..." -ForegroundColor Cyan
Write-Host "   - Setting initial replica count for '$deploymentName' to $minReplicas..."
Set-DeploymentReplicas -replicas $minReplicas -reason "Initialization"
$global:isLoadRunning = $false
$global:currentLoadLevel = 'none'
Cancel-PendingScaleDown # Clean up any jobs from previous runs if script was interrupted
Start-Sleep -Seconds 1

# --- Start HTTP Listener ---
Write-Host "`n[3] Starting HTTP Listener on $listenerUriPrefix ..." -ForegroundColor Cyan
if (-not ([System.Net.HttpListener]::IsSupported)) {
    Write-Error "HttpListener is not supported on this system."
    exit 1
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($listenerUriPrefix)

try {
    $listener.Start()
    Write-Host "$(Get-Date -Format 'HH:mm:ss') - Listener started. Waiting for requests from Frontend UI..." -ForegroundColor Green
    Write-Host "   >>> Ensure the Frontend UI is open and using the updated JavaScript."
    Write-Host "   >>> Press CTRL+C in this window to stop the listener and script."

    # Main loop to process requests
    while ($listener.IsListening) {
        $context = $null # Reset context for error handling clarity
        try {
            $context = $listener.GetContext() # Blocks until a request arrives
            $request = $context.Request
            $response = $context.Response

            Write-Host "$(Get-Date -Format 'HH:mm:ss') - Received request: $($request.HttpMethod) $($request.Url.AbsolutePath)" -ForegroundColor Magenta

            # --- CORS Handling ---
            $response.AddHeader("Access-Control-Allow-Origin", "*") # Allow requests from any origin (adjust if needed)

            # Handle Preflight OPTIONS request
            if ($request.HttpMethod -eq "OPTIONS") {
                $response.AddHeader("Access-Control-Allow-Methods", "POST, OPTIONS") # Specify allowed methods
                $response.AddHeader("Access-Control-Allow-Headers", "Content-Type") # Specify allowed headers
                $response.StatusCode = 204 # No Content for OPTIONS
                $response.StatusDescription = "No Content"
                Write-Host "$(Get-Date -Format 'HH:mm:ss') - Handled OPTIONS request (CORS preflight)." -ForegroundColor Gray
            }
            # Handle actual POST request to our endpoint
            elseif ($request.HttpMethod -eq "POST" -and $request.Url.AbsolutePath -eq "/notify") {

                $queryParams = $request.QueryString
                $action = $queryParams["action"]
                $level = $queryParams["level"] # Will be null if not present

                Write-Host "$(Get-Date -Format 'HH:mm:ss') - Action: '$action', Level: '$level'" -ForegroundColor Cyan

                if ($action -eq "start") {
                    Cancel-PendingScaleDown # Stop any scale-down timer if a new load starts
                    $global:isLoadRunning = $true
                    $targetReplicas = 0
                    switch ($level) {
                        'low'    { $targetReplicas = $lowReplicas; $global:currentLoadLevel = 'low' }
                        'medium' { $targetReplicas = $mediumReplicas; $global:currentLoadLevel = 'medium' }
                        'high'   { $targetReplicas = $highReplicas; $global:currentLoadLevel = 'high' }
                        default  {
                            Write-Warning "$(Get-Date -Format 'HH:mm:ss') - Received start command with unknown level '$level'. Defaulting to high.";
                            $targetReplicas = $highReplicas; $global:currentLoadLevel = 'high (unknown)'
                         }
                    }
                    # Set status code before writing content
                    $response.StatusCode = 200
                    $response.StatusDescription = "OK"
                    Write-HttpResponse -ResponseObject $response -Content "OK - Scale Up command sent for level '$level'."
                    # Perform scaling *after* sending response to make UI more responsive (optional)
                    Set-DeploymentReplicas -replicas $targetReplicas -reason "Start command received (Level: $level)"

                } elseif ($action -eq "stop") {
                     # Set status code before writing content
                    $response.StatusCode = 200
                    $response.StatusDescription = "OK"

                    if ($global:isLoadRunning) {
                        $global:isLoadRunning = $false
                        Write-Host "$(Get-Date -Format 'HH:mm:ss') - Stop command received. Initiating scale-down delay ($scaleDownDelaySeconds seconds)..." -ForegroundColor Red
                        Write-HttpResponse -ResponseObject $response -Content "OK - Scale Down Initiated (Delay: ${scaleDownDelaySeconds}s)."

                        # Start scale-down logic in a background job
                        Cancel-PendingScaleDown # Ensure no old job is running
                        $global:scaleDownJob = Start-Job -ScriptBlock {
                            param($delay, $deployName, $minReps)
                            # Simple scaling function within the job scope
                            Function Scale-Down-Job {
                                param($dName, $mReps)
                                Write-Host "$(Get-Date -Format 'HH:mm:ss') (Job $($MyInvocation.MyCommand.Name)) - Delay finished. Scaling '$dName' DOWN to $mReps replicas..." -ForegroundColor Cyan
                                try {
                                    kubectl scale deployment $dName --replicas=$mReps | Out-Null
                                    Write-Host "$(Get-Date -Format 'HH:mm:ss') (Job $($MyInvocation.MyCommand.Name)) - Scale down command sent."
                                } catch {
                                     Write-Warning "$(Get-Date -Format 'HH:mm:ss') (Job $($MyInvocation.MyCommand.Name)) - Scale down failed: $($_.Exception.Message)"
                                }
                            }
                            Write-Host "$(Get-Date -Format 'HH:mm:ss') (Job $($MyInvocation.MyCommand.Name)) - Waiting for $delay seconds before scaling down..."
                            Start-Sleep -Seconds $delay
                            Write-Host "$(Get-Date -Format 'HH:mm:ss') (Job $($MyInvocation.MyCommand.Name)) - Executing scale down."
                            Scale-Down-Job -dName $deployName -mReps $minReps

                        } -ArgumentList $scaleDownDelaySeconds, $deploymentName, $minReplicas -Name "ScaleDownJob" # Give the job a name

                    } else {
                        Write-Warning "$(Get-Date -Format 'HH:mm:ss') - Received stop command but load was not considered running."
                        Write-HttpResponse -ResponseObject $response -Content "OK - Notified Stop (System Already Idle)."
                    }
                    # Reset level regardless of whether it was running, as stop means idle
                    $global:currentLoadLevel = 'none'

                } else {
                    Write-Warning "$(Get-Date -Format 'HH:mm:ss') - Received unknown action: '$action'"
                    # Set status code before writing content
                    $response.StatusCode = 400
                    $response.StatusDescription = "Bad Request"
                    Write-HttpResponse -ResponseObject $response -Content "Error: Unknown action '$action'. Use 'start' or 'stop'."
                }
            }
            # Handle requests to paths other than /notify or methods other than POST/OPTIONS
            else {
                 Write-Warning "$(Get-Date -Format 'HH:mm:ss') - Received unsupported request: $($request.HttpMethod) $($request.Url.PathAndQuery)"
                 # Set status code before writing content
                 $response.StatusCode = 405
                 $response.StatusDescription = "Method Not Allowed"
                 Write-HttpResponse -ResponseObject $response -Content "Error: Method Not Allowed or Path Not Found."
            }

            # --- Important: Close the response stream AFTER writing content ---
            if ($response -ne $null -and $response.OutputStream.CanWrite) {
                 $response.OutputStream.Close()
            }


            # --- Background Job Management ---
            # Check if the scale-down job exists and has finished
            if ($global:scaleDownJob -ne $null -and $global:scaleDownJob.State -ne 'Running') {
                Write-Host "$(Get-Date -Format 'HH:mm:ss') - Background job '$($global:scaleDownJob.Name)' finished. State: $($global:scaleDownJob.State)" -ForegroundColor Gray
                # Display any output from the job
                Receive-Job $global:scaleDownJob | Out-Host
                # Remove the completed/failed job
                Remove-Job $global:scaleDownJob -Force
                $global:scaleDownJob = $null
            }

        } catch {
            # --- Central Error Handling for the Request Loop ---
            Write-Error "$(Get-Date -Format 'HH:mm:ss') - Error processing request: $($_.Exception.ToString())" # Log full exception
            # Attempt to send a 500 Internal Server Error response if possible
            if ($context -ne $null -and $context.Response -ne $null) {
                $errResponse = $context.Response
                try {
                    if ($errResponse.OutputStream.CanWrite -and -not $errResponse.HeadersSent) {
                       $errResponse.StatusCode = 500
                       $errResponse.StatusDescription = "Internal Server Error"
                       # Use the helper function even for error messages
                       Write-HttpResponse -ResponseObject $errResponse -Content "Internal Server Error occurred. Check listener script console."
                       $errResponse.OutputStream.Close()
                    }
                } catch {
                     Write-Warning "Failed to send 500 error response to client."
                }
            } else {
                 Write-Warning "Cannot send error response, context or response object is null."
            }
        } # End Try/Catch for request processing

    } # End while ($listener.IsListening)

} catch {
    Write-Error "$(Get-Date -Format 'HH:mm:ss') - FATAL: An error occurred with the listener: $($_.Exception.Message)"
} finally {
    # --- Cleanup ---
    if ($listener -ne $null -and $listener.IsListening) {
        Write-Host "$(Get-Date -Format 'HH:mm:ss') - Stopping listener..." -ForegroundColor Yellow
        $listener.Stop()
        $listener.Close()
        Write-Host "$(Get-Date -Format 'HH:mm:ss') - Listener stopped." -ForegroundColor Yellow
    }
    # Clean up any running background job on exit
    Cancel-PendingScaleDown # Use the function to ensure proper cleanup
    Write-Host "`n--- Listener Script Finished ---" -ForegroundColor Yellow
}