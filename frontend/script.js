document.addEventListener('DOMContentLoaded', () => {
    // --- Base API Paths (Relative to frontend server) ---
    // Nginx (or similar proxy) should handle routing these
    const MONO_API_BASE = '/api/monolith';
    const MS_USER_API_BASE = '/api/user';
    const MS_PRODUCT_API_BASE = '/api/product';
    const MS_ORDER_API_BASE = '/api/order';

    // --- URL for Local PowerShell Listener Script ---
    const LOCAL_NOTIFY_URL = 'http://localhost:9999/notify'; // Change port if needed in PowerShell script too

    // --- Hide URL Configuration Elements ---
    const configSection = document.getElementById('config-section');
    if (configSection) {
        configSection.style.display = 'none'; // Hide the configuration section
    }

    // --- Monolith Elements ---
    const monoUsernameInput = document.getElementById('mono-username');
    const monoCreateUserBtn = document.getElementById('mono-create-user-btn');
    const monoProductIdInput = document.getElementById('mono-product-id');
    const monoGetProductBtn = document.getElementById('mono-get-product-btn');
    const monoOrderUserIdInput = document.getElementById('mono-order-user-id');
    const monoOrderProductIdInput = document.getElementById('mono-order-product-id');
    const monoCreateOrderBtn = document.getElementById('mono-create-order-btn');
    const monoResponseArea = document.getElementById('mono-response-area');

    // --- Microservices Elements ---
    const msUsernameInput = document.getElementById('ms-username');
    const msCreateUserBtn = document.getElementById('ms-create-user-btn');
    const msUserIdDisplay = document.getElementById('ms-user-id-display');
    const msProductIdInput = document.getElementById('ms-product-id');
    const msGetProductBtn = document.getElementById('ms-get-product-btn');
    const msOrderUserIdInput = document.getElementById('ms-order-user-id');
    const msOrderProductIdInput = document.getElementById('ms-order-product-id');
    const msCreateOrderBtn = document.getElementById('ms-create-order-btn');
    const msResponseArea = document.getElementById('ms-response-area');

    // --- Autoscaling Elements ---
    const lowLoadBtn = document.getElementById('low-load-btn');
    const mediumLoadBtn = document.getElementById('medium-load-btn');
    const highLoadBtn = document.getElementById('high-load-btn');
    const stopLoadBtn = document.getElementById('stop-load-btn');
    const loadStatusSpan = document.getElementById('load-status');
    const loadResponseArea = document.getElementById('load-response-area');

    // --- Autoscaling State ---
    let isGeneratingLoad = false;
    let loadIntervalId = null;
    let requestCounter = 0;
    let currentLoadDescription = ''; // Store description like "Low Load (1 req/2s)"

    // --- Helper: API Fetch Function (unchanged) ---
    async function fetchApi(url, method = 'GET', body = null) {
        const options = {
            method: method,
            headers: {},
        };
        if (body) {
            options.headers['Content-Type'] = 'application/json';
            options.body = JSON.stringify(body);
        }

        try {
            const response = await fetch(url, options);
            const responseBody = await response.text();

            let parsedBody;
            try {
                 parsedBody = responseBody ? JSON.parse(responseBody) : null;
            } catch (e) {
                 parsedBody = responseBody;
            }

            if (!response.ok) {
                const errorData = (typeof parsedBody === 'object' && parsedBody !== null)
                                  ? parsedBody
                                  : { error: `Server returned non-JSON error: ${responseBody}` || response.statusText };
                throw { status: response.status, data: errorData };
            }
             return parsedBody;

        } catch (error) {
            if (error.status) {
                 throw error;
            } else {
                 // Network errors (service down, DNS issue, CORS, *or proxy misconfiguration*)
                 // *OR* error connecting to the local PowerShell listener
                 throw { status: 'Network/Proxy/Listener Error', data: { error: error.message } };
            }
        }
    }

     // --- Helper: Display Response (unchanged) ---
     function displayResponse(areaElement, data, type = 'success') {
         const timestamp = new Date().toLocaleTimeString();
         let message;
         // Handle potential non-JSON errors better in display
         if (type === 'error' && data && data.status && data.data) {
             // Specific handling for our structured errors
             message = `Error ${data.status}: ${JSON.stringify(data.data, null, 2)}`;
         } else if (type === 'error' && data instanceof Error) {
            // Handle generic JS errors
            message = `Error: ${data.message}`;
         } else if (typeof data === 'object' && data !== null) {
             message = JSON.stringify(data, null, 2);
         } else {
             message = String(data); // Convert non-objects/null to string
         }

         const newLog = `[${timestamp}] ${type.toUpperCase()}: \n${message}`;
         const currentLogs = areaElement.textContent.split('\n\n');
         const maxLogs = 50;
         const updatedLogs = [newLog, ...currentLogs.slice(0, maxLogs)].join('\n\n');

         areaElement.textContent = updatedLogs;
         areaElement.scrollTop = 0; // Scroll to top to see latest

         // Update class for simple single-response areas (mono/ms)
         if (areaElement === monoResponseArea || areaElement === msResponseArea) {
            areaElement.className = type === 'error' ? 'error' : 'success';
         }
     }

    // --- Helper: Display Error (calls displayResponse) ---
    function displayError(areaElement, error) {
        console.error("Caught Error:", error); // Log the raw error object for details
        // Pass the structured error {status, data} or the Error object itself
        displayResponse(areaElement, error, 'error');
    }


    // --- Monolith Event Listeners (unchanged) ---
    monoCreateUserBtn.addEventListener('click', async () => {
        const username = monoUsernameInput.value;
        if (!username) { displayError(monoResponseArea, { status: 'Input Error', data: { error: "Username cannot be empty" }}); return; }
        monoResponseArea.textContent = 'Calling API...';
        try {
            const data = await fetchApi(`${MONO_API_BASE}/user`, 'POST', { username });
            displayResponse(monoResponseArea, data);
            if (data && (data.user_id || data.userId)) {
                monoOrderUserIdInput.value = data.user_id || data.userId;
            }
        } catch (error) {
            displayError(monoResponseArea, error);
        }
    });

    monoGetProductBtn.addEventListener('click', async () => {
        const productId = monoProductIdInput.value;
        if (!productId) { displayError(monoResponseArea, { status: 'Input Error', data: { error: "Product ID cannot be empty" }}); return; }
        monoResponseArea.textContent = 'Calling API...';
        try {
            const data = await fetchApi(`${MONO_API_BASE}/product/${productId}`, 'GET');
            displayResponse(monoResponseArea, data);
        } catch (error) {
            displayError(monoResponseArea, error);
        }
    });

    monoCreateOrderBtn.addEventListener('click', async () => {
        const userId = monoOrderUserIdInput.value;
        const productId = monoOrderProductIdInput.value;
        if (!userId || !productId) { displayError(monoResponseArea, { status: 'Input Error', data: { error: "User ID and Product ID cannot be empty" }}); return; }
        monoResponseArea.textContent = 'Calling API...';
        try {
            const data = await fetchApi(`${MONO_API_BASE}/order`, 'POST', { user_id: userId, product_id: productId, quantity: 1 });
            displayResponse(monoResponseArea, data);
        } catch (error) {
            displayError(monoResponseArea, error);
        }
    });

    // --- Microservices Event Listeners (unchanged) ---
    msCreateUserBtn.addEventListener('click', async () => {
        const username = msUsernameInput.value;
        if (!username) { displayError(msResponseArea, { status: 'Input Error', data: { error: "Username cannot be empty" }}); return; }
        msResponseArea.textContent = 'Calling API...';
        msUserIdDisplay.textContent = '';
        try {
            const data = await fetchApi(`${MS_USER_API_BASE}/user`, 'POST', { username });
            displayResponse(msResponseArea, data);
            if (data && (data.user_id || data.userId)) {
                 const createdUserId = data.user_id || data.userId;
                 msOrderUserIdInput.value = createdUserId;
                 msUserIdDisplay.textContent = `(Created ID: ${createdUserId})`;
            }
        } catch (error) {
            displayError(msResponseArea, error);
        }
    });

    msGetProductBtn.addEventListener('click', async () => {
        const productId = msProductIdInput.value;
        if (!productId) { displayError(msResponseArea, { status: 'Input Error', data: { error: "Product ID cannot be empty" }}); return; }
        msResponseArea.textContent = 'Calling API...';
        try {
            const data = await fetchApi(`${MS_PRODUCT_API_BASE}/product/${productId}`, 'GET');
            displayResponse(msResponseArea, data);
        } catch (error) {
            displayError(msResponseArea, error);
        }
    });

    msCreateOrderBtn.addEventListener('click', async () => {
        const userId = msOrderUserIdInput.value;
        const productId = msOrderProductIdInput.value;
        if (!userId || !productId) { displayError(msResponseArea, { status: 'Input Error', data: { error: "User ID and Product ID cannot be empty" }}); return; }
        msResponseArea.textContent = 'Calling API...';
        try {
            const data = await fetchApi(`${MS_ORDER_API_BASE}/order`, 'POST', { user_id: userId, product_id: productId, quantity: 1 });
            displayResponse(msResponseArea, data);
        } catch (error) {
            displayError(msResponseArea, error);
        }
    });

    // --- Helper: Notify Local PowerShell Listener ---
    function notifyPowerShell(action, level = '') {
        let url = `${LOCAL_NOTIFY_URL}?action=${action}`;
        if (level) {
            url += `&level=${level}`;
        }
        console.log(`Notifying PowerShell Listener: POST ${url}`);
        fetch(url, {
            method: 'POST', // Use POST to potentially bypass caching and indicate action
            mode: 'cors',    // Essential for cross-origin request from browser to localhost
            headers: {
              // 'Content-Type': 'application/json' // Not strictly needed if body is empty
            },
            // body: JSON.stringify({}) // Optional: Send empty body or specific data
          })
            .then(response => {
                // Check if the response status indicates success (e.g., 200 OK, 204 No Content)
                if (!response.ok) {
                    console.warn(`Notification to PowerShell listener failed with status: ${response.status} ${response.statusText}`);
                    // Display a warning in the UI that the simulation script might not have reacted
                    displayResponse(loadResponseArea, `Warn: Could not notify scaling script (status ${response.status}). Is it running & accessible?`, 'warning');
                } else {
                    console.log('Notification to PowerShell listener seems successful.');
                    // Optionally provide positive feedback
                    // displayResponse(loadResponseArea, `Info: Notified scaling script (${action}${level ? ':'+level : ''}).`, 'info');
                }
                // Don't need to read the response body for this simple notification system
            })
            .catch(error => {
                // This usually catches network errors (listener down, DNS issues, CORS blocked *after* preflight if headers wrong, firewall)
                console.error('Error sending notification to PowerShell listener:', error);
                // Display a prominent error in the UI as the simulation is broken
                displayResponse(loadResponseArea, `ERROR: Cannot reach local scaling script at ${LOCAL_NOTIFY_URL}. Is it running? Check console. (Error: ${error.message})`, 'error');
            });
    }


    // --- Autoscaling Load Generation Functions ---

    function stopLoadGeneration() {
        if (!isGeneratingLoad) return; // Do nothing if not running

        if (loadIntervalId) {
            clearInterval(loadIntervalId);
            loadIntervalId = null;
        }
        isGeneratingLoad = false;
        const stoppedLevelDescription = currentLoadDescription; // Capture which level was stopped
        currentLoadDescription = '';

        // Update UI
        lowLoadBtn.disabled = false;
        mediumLoadBtn.disabled = false;
        highLoadBtn.disabled = false;
        stopLoadBtn.disabled = true; // Disable stop button
        loadStatusSpan.textContent = 'Load generation inactive.';
        displayResponse(loadResponseArea, `Load Stopped (${stoppedLevelDescription}). Notifying script...`, 'info');
        console.log("Stopped load generation.");

        // *** Notify PowerShell Script ***
        notifyPowerShell('stop'); // Notify that load stopped
    }

    function startLoadGeneration(intervalMs, description, levelKey) { // Added levelKey (e.g., 'low', 'medium', 'high')
        if (isGeneratingLoad) {
            console.warn("Load generation is already active. Stop the current load first.");
            displayResponse(loadResponseArea, "Load is already running. Stop it first.", 'warning');
            return; // Prevent starting multiple loads
        }

        isGeneratingLoad = true;
        requestCounter = 0;
        currentLoadDescription = description;

        // Update UI
        lowLoadBtn.disabled = true;
        mediumLoadBtn.disabled = true;
        highLoadBtn.disabled = true;
        stopLoadBtn.disabled = false; // Enable stop button

        loadStatusSpan.textContent = `Generating ${description}...`;
        loadResponseArea.textContent = ''; // Clear previous load logs
        displayResponse(loadResponseArea, `Starting ${description} (interval: ${intervalMs}ms). Notifying script...`, 'info');
        console.log(`Starting ${description}...`);

        // *** Notify PowerShell Script ***
        notifyPowerShell('start', levelKey); // Pass the specific level key ('low', 'medium', 'high')

        // Use values from MS Order section or defaults for load testing
        const userIdForLoad = msOrderUserIdInput.value || 'loadTestUser';
        const productIdForLoad = msOrderProductIdInput.value || 'loadTestProd';
        const loadPayload = { user_id: userIdForLoad, product_id: productIdForLoad, quantity: 1 };

        loadIntervalId = setInterval(async () => {
            // Interval callback safeguard
            if (!isGeneratingLoad) {
                 clearInterval(loadIntervalId);
                 loadIntervalId = null;
                 return;
            }

            requestCounter++;
            const currentRequest = requestCounter; // Capture counter for async context

            try {
                // Use relative path for order service load (handled by Nginx proxy)
                await fetchApi(`${MS_ORDER_API_BASE}/order`, 'POST', loadPayload);
                // Optional: Log success occasionally
                 if (currentRequest % 50 === 0) { // Log every 50 requests
                     console.log(`Sent ${currentRequest} load requests for ${currentLoadDescription}.`);
                     loadStatusSpan.textContent = `Generating ${currentLoadDescription}... (${currentRequest} sent)`;
                     // displayResponse(loadResponseArea, `Req ${currentRequest}: OK`, 'success'); // Can uncomment for verbose success
                 }
            } catch (error) {
                 // Log API errors to the load response area
                 const errorMsg = `Req ${currentRequest}: Error ${error.status || 'N/A'} - ${JSON.stringify(error.data || error.message)}`;
                 console.warn(errorMsg);
                 displayResponse(loadResponseArea, errorMsg, 'error');
                 // Consider stopping load generation on persistent errors?
                 // if (error.status === 'Network/Proxy/Listener Error' || (error.status >= 500 && error.status <= 599) ) {
                 //    console.error("Stopping load due to persistent backend/proxy errors.");
                 //    displayResponse(loadResponseArea, `ERROR: Stopping load generation due to persistent errors (Status: ${error.status}).`, 'error');
                 //    stopLoadGeneration();
                 // }
             }

        }, intervalMs); // Use the specific interval for this load level
    }

    // --- Autoscaling Event Listeners (Updated to pass levelKey) ---
    lowLoadBtn.addEventListener('click', () => {
        // Low Load: 1 request per 2 seconds = 2000ms interval
        startLoadGeneration(2000, 'Low Load (1 req/2s)', 'low'); // Pass 'low' as levelKey
    });

    mediumLoadBtn.addEventListener('click', () => {
        // Medium Load: 2 requests per second = 500ms interval
        startLoadGeneration(500, 'Medium Load (2 req/s)', 'medium'); // Pass 'medium' as levelKey
    });

    highLoadBtn.addEventListener('click', () => {
        // High Load: 10 requests per second = 100ms interval
        startLoadGeneration(100, 'High Load (10 req/s)', 'high'); // Pass 'high' as levelKey
    });

    stopLoadBtn.addEventListener('click', () => {
        stopLoadGeneration(); // No levelKey needed for stop
    });


    // --- Initial Setup ---
    monoResponseArea.textContent = 'Responses will appear here...';
    msResponseArea.textContent = 'Responses will appear here...';
    loadResponseArea.textContent = 'Load generation status and errors will appear here...';
    stopLoadBtn.disabled = true; // Ensure stop button is disabled initially
    console.log("Frontend script initialized. Ready to interact with backend services via proxy and notify local listener.");
});