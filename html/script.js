// Enhanced NUI Variables with error handling
let laptopOpen = false;
let activeAppWindow = null;
let activeAppScreen = null;
let nearbyVehicles = [];
let soundEnabled = false;
let useAnimations = true;
let darkTheme = true;
let batteryLevel = 100;
let isCharging = false;
let currentLevel = 1;
let currentXP = 0;
let nextLevelXP = 100;
let currentLevelName = "Script Kiddie";
let phoneLastUsed = Date.now();

// Error handling configuration
const ErrorConfig = {
    maxRetries: 3,
    retryDelay: 500,
    requestTimeout: 10000,
    logLevel: 'INFO'
};

// Health monitoring
const NUIHealth = {
    lastServerResponse: Date.now(),
    failedRequests: 0,
    connected: true
};

// Enhanced logging functions
function safeLogError(message, context) {
    const timestamp = new Date().toISOString();
    const contextStr = context ? ` [${context}]` : '';
    console.error(`[qb-hackerjob:nui:ERROR] [${timestamp}] ${message}${contextStr}`);
}

function safeLogInfo(message, context) {
    if (ErrorConfig.logLevel === 'DEBUG' || ErrorConfig.logLevel === 'INFO') {
        const timestamp = new Date().toISOString();
        const contextStr = context ? ` [${context}]` : '';
        console.log(`[qb-hackerjob:nui:INFO] [${timestamp}] ${message}${contextStr}`);
    }
}

function safeLogDebug(message, context) {
    if (ErrorConfig.logLevel === 'DEBUG') {
        const timestamp = new Date().toISOString();
        const contextStr = context ? ` [${context}]` : '';
        console.log(`[qb-hackerjob:nui:DEBUG] [${timestamp}] ${message}${contextStr}`);
    }
}

// Safe POST request wrapper with retry logic
function safePost(url, data, successCallback, errorCallback, retries = ErrorConfig.maxRetries) {
    if (!url || typeof url !== 'string') {
        safeLogError('Invalid URL provided to safePost');
        if (errorCallback) errorCallback(new Error('Invalid URL'));
        return;
    }
    
    function attemptRequest(attempt) {
        const timeoutId = setTimeout(() => {
            safeLogError(`Request timeout for ${url} on attempt ${attempt}`);
            if (attempt < retries) {
                setTimeout(() => attemptRequest(attempt + 1), ErrorConfig.retryDelay * attempt);
            } else {
                NUIHealth.failedRequests++;
                const error = new Error('Request timeout after all retries');
                if (errorCallback) errorCallback(error);
            }
        }, ErrorConfig.requestTimeout);
        
        try {
            $.post(url, JSON.stringify(data || {}), function(response) {
                clearTimeout(timeoutId);
                NUIHealth.lastServerResponse = Date.now();
                NUIHealth.connected = true;
                safeLogDebug(`Request successful: ${url}`);
                if (successCallback) successCallback(response);
            }).fail(function(xhr, status, error) {
                clearTimeout(timeoutId);
                safeLogError(`Request failed on attempt ${attempt}/${retries}: ${url} - ${error}`);
                if (attempt < retries) {
                    setTimeout(() => attemptRequest(attempt + 1), ErrorConfig.retryDelay * attempt);
                } else {
                    NUIHealth.failedRequests++;
                    if (errorCallback) errorCallback(new Error(`Request failed: ${error}`));
                }
            });
        } catch (err) {
            clearTimeout(timeoutId);
            safeLogError(`Exception during request: ${url} - ${err.message}`);
            if (attempt < retries) {
                setTimeout(() => attemptRequest(attempt + 1), ErrorConfig.retryDelay * attempt);
            } else {
                if (errorCallback) errorCallback(err);
            }
        }
    }
    
    attemptRequest(1);
}

// Safe DOM manipulation wrapper
function safeQuerySelector(selector, context = document) {
    try {
        const element = context.querySelector(selector);
        if (!element) {
            safeLogError(`Element not found: ${selector}`);
        }
        return element;
    } catch (err) {
        safeLogError(`Error selecting element: ${selector} - ${err.message}`);
        return null;
    }
}

function safeQuerySelectorAll(selector, context = document) {
    try {
        const elements = context.querySelectorAll(selector);
        return elements;
    } catch (err) {
        safeLogError(`Error selecting elements: ${selector} - ${err.message}`);
        return [];
    }
}

// Safe event listener wrapper
function safeAddEventListener(element, event, handler, options) {
    if (!element) {
        safeLogError('No element provided to safeAddEventListener');
        return false;
    }
    
    if (typeof handler !== 'function') {
        safeLogError('Invalid handler provided to safeAddEventListener');
        return false;
    }
    
    try {
        element.addEventListener(event, function(e) {
            try {
                handler(e);
            } catch (err) {
                safeLogError(`Error in event handler for ${event}: ${err.message}`);
            }
        }, options);
        return true;
    } catch (err) {
        safeLogError(`Failed to add event listener for ${event}: ${err.message}`);
        return false;
    }
}

// Network health monitoring
function monitorNetworkHealth() {
    const now = Date.now();
    const timeSinceLastResponse = now - NUIHealth.lastServerResponse;
    
    if (timeSinceLastResponse > 30000) { // 30 seconds
        NUIHealth.connected = false;
        safeLogError('Network connection appears to be lost');
    }
    
    if (NUIHealth.failedRequests > 5) {
        safeLogError(`High number of failed requests: ${NUIHealth.failedRequests}`);
    }
}

// Start network monitoring
setInterval(monitorNetworkHealth, 5000);

// Enhanced DOM Ready with error handling
$(document).ready(function() {
    safeLogInfo('DOM ready, initializing laptop interface');
    
    try {
        // Initialize with error handling
        resetUI();
        setupEventHandlers();
        setupPhoneEventHandlers();
        setupTouchGestures();
        updateClock();
        updateGreeting();
        
        safeLogInfo('Laptop interface initialization completed successfully');
    } catch (err) {
        safeLogError('Failed to initialize laptop interface: ' + err.message);
        // Try to show a basic error message
        try {
            document.body.innerHTML = '<div style="color: red; text-align: center; margin-top: 50px; font-size: 18px;">Error initializing laptop interface. Please restart the resource.</div>';
        } catch (e) {
            safeLogError('Critical error - unable to show error message');
        }
    }

    // Safe UI modifications
    try {
        // ### DISABLE NEARBY TAB VISUALLY ###
        // Hide the nearby tab and its content pane permanently
        $('#plate-lookup-app .tab[data-tab="nearby"]').hide();
        $('#nearby-tab').hide();
        // Ensure search is the default active tab (might be redundant with openApp logic but safe)
        $('#plate-lookup-app .tab[data-tab="search"]').addClass('active');
        $('#search-tab').addClass('active');
        // ##################################
        
        safeLogDebug('UI modifications completed successfully');
    } catch (err) {
        safeLogError('Failed to apply UI modifications: ' + err.message);
    }

    // Safe clock updater with error handling
    try {
        let clockUpdateInterval = 60000; // Start with 1 minute
        setInterval(() => {
            try {
                updateClock();
                // Reduce frequency if phone has been idle
                const now = Date.now();
                if (now - phoneLastUsed > 300000) { // If idle for 5+ minutes
                    clockUpdateInterval = 120000; // Update every 2 minutes when idle
                } else {
                    clockUpdateInterval = 60000; // Normal frequency when active
                }
            } catch (err) {
                safeLogError('Error updating clock: ' + err.message);
            }
        }, clockUpdateInterval);
        
        safeLogDebug('Clock updater initialized successfully');
    } catch (err) {
        safeLogError('Failed to initialize clock updater: ' + err.message);
    }
});

// Enhanced event handlers setup with error handling
function setupEventHandlers() {
    safeLogDebug('Setting up event handlers');
    
    try {
        // Safe desktop icon click handler
        $('.desktop-icon').on('click', function() {
            try {
                const appName = $(this).data('app');
                if (!appName) {
                    safeLogError('No app name found for desktop icon');
                    return;
                }
                openApp(appName);
            } catch (err) {
                safeLogError('Error handling desktop icon click: ' + err.message);
            }
        });

        // Safe window controls
        $('.window-close').on('click', function() {
            try {
                const appWindow = $(this).closest('.app-window');
                const windowId = appWindow.attr('id');
                if (!windowId) {
                    safeLogError('No window ID found for close button');
                    return;
                }
                closeApp(windowId);
            } catch (err) {
                safeLogError('Error handling window close: ' + err.message);
            }
        });

        $('.window-minimize').on('click', function() {
            try {
                const appWindow = $(this).closest('.app-window');
                const windowId = appWindow.attr('id');
                if (!windowId) {
                    safeLogError('No window ID found for minimize button');
                    return;
                }
                minimizeApp(windowId);
            } catch (err) {
                safeLogError('Error handling window minimize: ' + err.message);
            }
        });

    // Tab navigation
    $('.tab').on('click', function() {
        const tab = $(this).data('tab');
        const parentWindow = $(this).closest('.app-window');

        // Deactivate all tabs and panes in this window
        $(parentWindow).find('.tab').removeClass('active');
        $(parentWindow).find('.tab-pane').removeClass('active');

        // Activate the clicked tab and corresponding pane
        $(this).addClass('active');

        let paneId;
        // Map tab IDs to pane IDs
        if (tab === 'nearby') {
            // ### DISABLED NEARBY VEHICLES ###
            console.log('Nearby tab clicked - DISABLED');
            // Optionally, immediately switch to the search tab instead
            // $(parentWindow).find('.tab[data-tab="search"]').click();
            // return; // Prevent further processing
            // ### For now, just allow clicking but do nothing ###
            paneId = 'nearby-tab';
            // updateNearbyVehicles(); // Don't call this
            // #############################
        } else if (tab === 'search') {
            paneId = 'search-tab';
        } else if (tab === 'results') {
            paneId = 'results-tab';
        } else if (tab === 'phone-search') {
            paneId = 'phone-search-tab';
        } else if (tab === 'phone-results') {
            paneId = 'phone-results-tab';
        } else if (tab === 'radio-search') {
            paneId = 'radio-search-tab';
        } else if (tab === 'radio-results') {
            paneId = 'radio-results-tab';
        }

        $(`#${paneId}`).addClass('active');
    });

    // Battery controls are now handled via document delegation in createBatteryIndicator()

    // App-specific handlers

        // Safe plate lookup handlers
        $('#search-plate').on('click', function() {
            try {
                const plateInput = $('#plate-input');
                if (plateInput.length === 0) {
                    safeLogError('Plate input element not found');
                    return;
                }
                
                const plate = plateInput.val();
                if (!plate || typeof plate !== 'string') {
                    safeLogError('Invalid plate input value');
                    return;
                }
                
                const trimmedPlate = plate.trim();
                if (trimmedPlate.length > 0) {
                    searchPlate(trimmedPlate);
                } else {
                    safeLogError('Empty plate input provided');
                }
            } catch (err) {
                safeLogError('Error handling plate search button: ' + err.message);
            }
        });

        $('#plate-input').on('keyup', function(e) {
            try {
                if (e.keyCode === 13) {
                    const plate = $(this).val();
                    if (!plate || typeof plate !== 'string') {
                        safeLogError('Invalid plate input value on keyup');
                        return;
                    }
                    
                    const trimmedPlate = plate.trim();
                    if (trimmedPlate.length > 0) {
                        searchPlate(trimmedPlate);
                    }
                }
            } catch (err) {
                safeLogError('Error handling plate input keyup: ' + err.message);
            }
        });

    $('#refresh-nearby').on('click', function() {
        // ### DISABLED NEARBY VEHICLES ###
        console.log('Refresh nearby clicked - DISABLED');
        // updateNearbyVehicles(); // Don't call this
        // #############################
    });

    // Phone Tracker
    $('#track-phone').on('click', function() {
        const phone = $('#phone-input').val().trim();
        if (phone.length > 0) {
            trackPhone(phone);
        }
    });

    $('#phone-input').on('keyup', function(e) {
        if (e.keyCode === 13) {
            const phone = $(this).val().trim();
            if (phone.length > 0) {
                trackPhone(phone);
            }
        }
    });

    // Radio Decrypter
    $('#decrypt-radio').on('click', function() {
        const frequency = $('#frequency-input').val().trim();
        if (frequency.length > 0) {
            decryptRadio(frequency);
        }
    });

    $('#frequency-input').on('keyup', function(e) {
        if (e.keyCode === 13) {
            const frequency = $(this).val().trim();
            if (frequency.length > 0) {
                decryptRadio(frequency);
            }
        }
    });

        // Safe escape key handler
        $(document).on('keyup', function(e) {
            try {
                if (e.keyCode === 27) {
                    closePhone();
                }
            } catch (err) {
                safeLogError('Error handling escape key: ' + err.message);
            }
        });
        
        safeLogDebug('Event handlers setup completed successfully');
    } catch (err) {
        safeLogError('Failed to setup event handlers: ' + err.message);
    }
}

// Setup phone interface event handlers
function setupPhoneEventHandlers() {
    try {
        // App card clicks
        $(document).on('click', '.app-card', function() {
            const appName = $(this).data('app');
            console.log('App card clicked:', appName);
            if (appName) {
                openApp(appName);
            }
        });

        // Back button clicks
        $(document).on('click', '.back-button', function() {
            goToHome();
        });

        // Tab navigation
        $(document).on('click', '.tab-item', function() {
            const tabName = $(this).data('tab');
            if (tabName) {
                switchTab(tabName);
            }
        });

        // Bottom navigation
        $(document).on('click', '.nav-item', function() {
            const tabName = $(this).data('tab');
            if (tabName) {
                switchBottomNav(tabName);
            }
        });

        // Primary buttons
        $(document).on('click', '#search-plate', function() {
            const plate = $('#plate-input').val().trim();
            console.log('Search plate clicked:', plate);
            if (plate) {
                searchPlate(plate);
            }
        });

        $(document).on('click', '#track-phone', function() {
            const phoneNumber = $('#phone-input').val().trim();
            if (phoneNumber) {
                trackPhone(phoneNumber);
            }
        });

        $(document).on('click', '#decrypt-radio', function() {
            const frequency = $('#frequency-input').val().trim();
            if (frequency) {
                decryptRadio(frequency);
            }
        });

        // Escape key to close phone
        $(document).on('keydown', function(e) {
            if (e.key === 'Escape' && laptopOpen) {
                closePhone();
            }
        });

        // Setup phone dragging
        setupPhoneDragging();

        safeLogInfo('Phone event handlers setup successfully');
    } catch (err) {
        safeLogError('Failed to setup phone event handlers: ' + err.message);
    }
}

// Setup phone dragging functionality
function setupPhoneDragging() {
    try {
        let isDragging = false;
        let dragOffset = { x: 0, y: 0 };
        
        const phoneContainer = $('#phone-container');
        
        // Mouse events
        phoneContainer.on('mousedown', function(e) {
            // Only start dragging if clicking on the phone container itself or status bar
            if (e.target === this || $(e.target).closest('.status-bar').length > 0) {
                isDragging = true;
                const containerRect = this.getBoundingClientRect();
                dragOffset.x = e.clientX - containerRect.left;
                dragOffset.y = e.clientY - containerRect.top;
                $(this).css('cursor', 'grabbing');
                e.preventDefault();
            }
        });

        $(document).on('mousemove', function(e) {
            if (isDragging) {
                const phoneContainer = $('#phone-container');
                const newX = e.clientX - dragOffset.x;
                const newY = e.clientY - dragOffset.y;
                
                // Keep phone within viewport bounds
                const maxX = window.innerWidth - phoneContainer.outerWidth();
                const maxY = window.innerHeight - phoneContainer.outerHeight();
                
                const boundedX = Math.max(0, Math.min(newX, maxX));
                const boundedY = Math.max(0, Math.min(newY, maxY));
                
                phoneContainer.css({
                    'left': boundedX + 'px',
                    'top': boundedY + 'px',
                    'transform': 'none' // Remove centering transform when dragging
                });
                e.preventDefault();
            }
        });

        $(document).on('mouseup', function() {
            if (isDragging) {
                isDragging = false;
                $('#phone-container').css('cursor', 'default');
            }
        });

        safeLogInfo('Phone dragging setup completed');
    } catch (err) {
        safeLogError('Failed to setup phone dragging: ' + err.message);
    }
}

// Open an app - removed duplicate, using more detailed version below

// Switch tabs within an app
function switchTab(tabName) {
    try {
        // Find the parent app container
        const appContainer = $(event.target).closest('.app-screen');
        
        // Update tab items
        appContainer.find('.tab-item').removeClass('active');
        $(event.target).closest('.tab-item').addClass('active');
        
        // Update tab content
        appContainer.find('.tab-content').removeClass('active');
        appContainer.find(`#${tabName}-tab`).addClass('active');
        
        safeLogInfo('Switched to tab: ' + tabName);
    } catch (err) {
        safeLogError('Error switching tab: ' + err.message);
    }
}

// Switch bottom navigation
function switchBottomNav(tabName) {
    try {
        // Update nav items
        $('.nav-item').removeClass('active');
        $(event.target).closest('.nav-item').addClass('active');
        
        // Handle navigation
        if (tabName === 'home') {
            goToHome();
        }
        
        safeLogInfo('Switched bottom nav to: ' + tabName);
    } catch (err) {
        safeLogError('Error switching bottom nav: ' + err.message);
    }
}

// Track phone function placeholder
function trackPhone(phoneNumber) {
    try {
        safeLogInfo('Tracking phone: ' + phoneNumber);
        // Add your phone tracking logic here
        showActionOverlay('Tracking device...');
    } catch (err) {
        safeLogError('Error tracking phone: ' + err.message);
    }
}

// Switch to results tab in plate lookup app
function switchToResultsTab() {
    try {
        const app = $('#plate-lookup-app');
        if (app.length > 0) {
            // Switch tab buttons
            app.find('.tab-item').removeClass('active');
            app.find('.tab-item[data-tab="results"]').addClass('active');
            
            // Switch tab content
            app.find('.tab-content').removeClass('active');
            app.find('#results-tab').addClass('active');
            
            safeLogDebug('Switched to results tab');
        }
    } catch (err) {
        safeLogError('Error switching to results tab: ' + err.message);
    }
}

// Decrypt radio function placeholder  
function decryptRadio(frequency) {
    try {
        safeLogInfo('Decrypting radio frequency: ' + frequency);
        // Add your radio decryption logic here
        showActionOverlay('Decrypting signal...');
    } catch (err) {
        safeLogError('Error decrypting radio: ' + err.message);
    }
}

// Reset UI state
function resetUI() {
    laptopOpen = false;
    activeAppWindow = null;
    $('#phone-container').removeClass('visible').addClass('hidden');
    $('.app-screen').addClass('hidden');
    $('.boot-progress-bar').css('width', '0%');
    $('#home-screen').addClass('hidden');
    $('#boot-screen').removeClass('hidden');
    batteryLevel = 100;
    isCharging = false;
    currentLevel = 1;
    currentXP = 0;
    nextLevelXP = 100;
    currentLevelName = "Script Kiddie";
    updateHackerStatsDisplay(); // Reset display
}

// Enhanced phone opening function with error handling
function openPhone(data) {
    if (laptopOpen) {
        safeLogInfo('Phone already open');
        return;
    }

    safeLogInfo('Opening laptop with data:', data ? 'provided' : 'not provided');

    try {
        // Safe data processing
        if (data && typeof data === 'object') {
            try {
                soundEnabled = false; // Force disable sound for performance
                useAnimations = data.animations !== undefined ? Boolean(data.animations) : false;
                darkTheme = data.theme === 'dark';
                
                // Safe number validation
                batteryLevel = (typeof data.batteryLevel === 'number' && data.batteryLevel >= 0 && data.batteryLevel <= 100) 
                    ? data.batteryLevel : 100;
                isCharging = Boolean(data.charging);
                
                // Safe hacker stats validation
                currentLevel = (typeof data.level === 'number' && data.level > 0) ? data.level : 1;
                currentXP = (typeof data.xp === 'number' && data.xp >= 0) ? data.xp : 0;
                nextLevelXP = (typeof data.nextLevelXP === 'number' && data.nextLevelXP > 0) ? data.nextLevelXP : 100;
                currentLevelName = (typeof data.levelName === 'string' && data.levelName.length > 0) 
                    ? data.levelName : "Script Kiddie";
                
                safeLogDebug('Data processed successfully - Level: ' + currentLevel + ', XP: ' + currentXP + ', Battery: ' + batteryLevel + '%');
            } catch (err) {
                safeLogError('Error processing laptop data: ' + err.message);
                // Set safe defaults
                batteryLevel = 100;
                isCharging = false;
                currentLevel = 1;
                currentXP = 0;
                nextLevelXP = 100;
                currentLevelName = "Script Kiddie";
            }
        } else {
            safeLogDebug('No data provided, using defaults');
            // Set safe defaults
            batteryLevel = 100;
            isCharging = false;
            currentLevel = 1;
            currentXP = 0;
            nextLevelXP = 100;
            currentLevelName = "Script Kiddie";
        }

        phoneOpen = true;
        phoneLastUsed = Date.now();

        // Safe UI setup
        const phoneContainer = $('#phone-container');
        if (phoneContainer.length === 0) {
            throw new Error('Phone container element not found');
        }
        
        phoneContainer.removeClass('hidden').addClass('visible');
        
        // Safe cleanup of existing battery elements
        try {
            $('#battery-indicator, #battery-menu').remove();
        } catch (err) {
            safeLogError('Error removing existing battery elements: ' + err.message);
        }
        
        // Safe battery indicator creation
        try {
            createBatteryIndicator();
            updateBatteryDisplay(batteryLevel, isCharging);
        } catch (err) {
            safeLogError('Error creating battery indicator: ' + err.message);
        }
        
        // Safe stats display update
        try {
            updateHackerStatsDisplay(currentLevel, currentXP, nextLevelXP, currentLevelName);
        } catch (err) {
            safeLogError('Error updating hacker stats display: ' + err.message);
        }

        // Safe boot sequence
        if (!useAnimations) {
            try {
                const bootScreen = $('#boot-screen');
                const homeScreen = $('#home-screen');
                
                if (bootScreen.length > 0) {
                    bootScreen.addClass('hidden');
                }
                if (homeScreen.length > 0) {
                    homeScreen.removeClass('hidden');
                }
                
                safeLogDebug('Phone opened successfully without animations');
                return;
            } catch (err) {
                safeLogError('Error during no-animation boot: ' + err.message);
                // Continue with animated boot as fallback
            }
        }

        // Safe animated boot sequence
        try {
            const bootScreen = $('#boot-screen');
            const progressBar = $('.boot-progress-bar');
            const bootText = $('.boot-text');
            
            if (bootScreen.length === 0 || progressBar.length === 0 || bootText.length === 0) {
                throw new Error('Boot screen elements not found');
            }
            
            bootScreen.removeClass('hidden');
            progressBar.css('width', '0%');
            bootText.text('INITIALIZING SYSTEM...');

            // Safe boot sequence with error handling
            const bootSteps = [
                { text: 'INITIALIZING SYSTEM...', progress: 25 },
                { text: 'LOADING MODULES...', progress: 75 },
                { text: 'SYSTEM READY', progress: 100 }
            ];

            let stepIndex = 0;
            const fastBootSequence = setInterval(() => {
                try {
                    if (stepIndex < bootSteps.length) {
                        const step = bootSteps[stepIndex];
                        const bootTextElement = $('.boot-text');
                        const progressBarElement = $('.boot-progress-bar');
                        
                        if (bootTextElement.length > 0) {
                            bootTextElement.text(step.text);
                        }
                        if (progressBarElement.length > 0) {
                            progressBarElement.css('width', `${step.progress}%`);
                        }
                        
                        stepIndex++;
                    } else {
                        clearInterval(fastBootSequence);
                        
                        // Safe transition to desktop
                        setTimeout(() => {
                            try {
                                const bootScreenElement = $('#boot-screen');
                                const homeScreenElement = $('#home-screen');
                                
                                if (bootScreenElement.length > 0) {
                                    bootScreenElement.addClass('hidden');
                                }
                                if (homeScreenElement.length > 0) {
                                    homeScreenElement.removeClass('hidden');
                                }
                                
                                safeLogInfo('Laptop boot sequence completed successfully');
                            } catch (err) {
                                safeLogError('Error during desktop transition: ' + err.message);
                            }
                        }, 200);
                    }
                } catch (err) {
                    safeLogError('Error during boot sequence step: ' + err.message);
                    clearInterval(fastBootSequence);
                    // Force show home screen as fallback
                    try {
                        $('#boot-screen').addClass('hidden');
                        $('#home-screen').removeClass('hidden');
                    } catch (e) {
                        safeLogError('Critical error during boot fallback: ' + e.message);
                    }
                }
            }, 300);
        } catch (err) {
            safeLogError('Error setting up boot sequence: ' + err.message);
            // Fallback to direct home screen show
            try {
                $('#boot-screen').addClass('hidden');
                $('#home-screen').removeClass('hidden');
            } catch (e) {
                safeLogError('Critical error during boot fallback: ' + e.message);
            }
        }
    } catch (err) {
        safeLogError('Error in openPhone function: ' + err.message);
        // Reset state on error
        phoneOpen = false;
    }
}

// Create battery indicator for taskbar
function createBatteryIndicator() {
    console.log('Creating battery indicator');

    // Remove if it already exists
    $('#battery-indicator, #battery-menu').remove();

    // Add battery element to status bar
    $('.status-right').append(`
        <div id="battery-indicator" class="battery-indicator">
            <div class="battery-icon"></div>
            <div class="battery-percentage">100%</div>
        </div>
        <div id="battery-menu" class="battery-menu hidden">
            <div class="battery-header">Battery Status</div>
            <div class="battery-level-display">
                <div class="battery-meter">
                    <div class="battery-meter-fill"></div>
                </div>
                <div class="battery-percentage-large">100%</div>
                <div class="battery-status">Normal</div>
            </div>
            <div class="battery-actions">
                <button id="replace-battery" class="battery-action-btn">Replace Battery</button>
                <button id="toggle-charger" class="battery-action-btn">Connect Charger</button>
            </div>
        </div>
    `);

    console.log('Battery indicator created, elements:', {
        indicator: $('#battery-indicator').length,
        menu: $('#battery-menu').length,
        replaceBtn: $('#replace-battery').length,
        chargerBtn: $('#toggle-charger').length
    });

    // Unbind any existing event handlers to prevent duplicates
    $(document).off('click', '#battery-indicator');
    $(document).off('click', '#battery-menu');
    $(document).off('click', '#replace-battery');
    $(document).off('click', '#toggle-charger');

    // Add click event for battery indicator to show menu using direct event binding
    $(document).on('click', '#battery-indicator', function(e) {
        e.stopPropagation();

        // Toggle menu visibility
        const menu = $('#battery-menu');
        const isHidden = menu.hasClass('hidden');
        console.log('Battery indicator clicked, menu hidden:', isHidden);

        if (isHidden) {
            menu.removeClass('hidden');
        } else {
            menu.addClass('hidden');
        }

        // Hide menu when clicking elsewhere
        $(document).one('click', function() {
            $('#battery-menu').addClass('hidden');
            console.log('Document clicked, hiding battery menu');
        });
    });

    $(document).on('click', '#battery-menu', function(e) {
        e.stopPropagation();
        console.log('Click inside battery menu - not hiding');
    });

    // Replace direct event bindings with document delegation for battery action buttons
    // This ensures the events work even if the elements are recreated
    $(document).on('click', '#replace-battery', function(e) {
        e.stopPropagation();
        console.log('Replace battery clicked - delegated event');

        // Display loading state
        const button = $(this);
        const originalText = button.text();
        button.text('REPLACING...');
        button.addClass('disabled');

        $.post('https://qb-hackerjob/replaceBattery', JSON.stringify({}), function(response) {
            console.log('Replace battery response:', response);

            // Reset button
            button.text(originalText);
            button.removeClass('disabled');

            if (response.success) {
                updateBatteryDisplay(response.batteryLevel);
            } else {
                // Show error message
                const errorMsg = response.message || "Failed to replace battery";
                $('.battery-status').text(errorMsg).css('color', 'red');
                setTimeout(() => {
                    $('.battery-status').css('color', '');
                }, 3000);
            }
        }).fail(function() {
            console.error('Failed to post replaceBattery event');

            // Reset button
            button.text(originalText);
            button.removeClass('disabled');
        });
    });

    $(document).on('click', '#toggle-charger', function(e) {
        e.stopPropagation();
        console.log('Toggle charger clicked - delegated event');

        // Display loading state
        const button = $(this);
        const originalText = button.text();
        button.text('PROCESSING...');
        button.addClass('disabled');

        $.post('https://qb-hackerjob/toggleCharger', JSON.stringify({}), function(response) {
            console.log('Toggle charger response:', response);

            // Reset button
            button.text(originalText);
            button.removeClass('disabled');

            if (response.success) {
                updateBatteryDisplay(response.batteryLevel, response.charging);
            } else {
                // Show error message
                const errorMsg = response.message || "Failed to toggle charger";
                $('.battery-status').text(errorMsg).css('color', 'red');
                setTimeout(() => {
                    $('.battery-status').css('color', '');
                }, 3000);
            }
        }).fail(function() {
            console.error('Failed to post toggleCharger event');

            // Reset button
            button.text(originalText);
            button.removeClass('disabled');
        });
    });
}

// Optimized battery display update with batched DOM operations
function updateBatteryDisplay(level, charging) {
    console.log('Updating battery display:', { level: level, charging: charging });

    batteryLevel = level;
    isCharging = charging;

    // Make sure we have the battery UI elements
    if ($('#battery-indicator').length === 0) {
        console.log('Creating battery indicator because it was missing');
        createBatteryIndicator();
    }

    // Round the battery level to zero decimal places for display
    const displayLevel = Math.round(batteryLevel);

    // Batch DOM updates for better performance
    const updates = [];
    const batteryIcon = $('.battery-icon');
    
    // Prepare all updates
    updates.push(() => $('.battery-percentage').text(`${displayLevel}%`));
    updates.push(() => $('.battery-percentage-large').text(`${displayLevel}%`));
    updates.push(() => $('.battery-meter-fill').css('width', `${displayLevel}%`));
    
    // Remove all battery state classes first
    updates.push(() => batteryIcon.removeClass('battery-high battery-medium battery-low battery-critical battery-charging'));

    let statusText = '';
    let buttonText = '';
    let iconClass = '';

    if (isCharging) {
        iconClass = 'battery-charging';
        statusText = 'Charging';
        buttonText = 'Disconnect Charger';
    } else {
        buttonText = 'Connect Charger';
        if (displayLevel >= 60) {
            iconClass = 'battery-high';
            statusText = 'Normal';
        } else if (displayLevel >= 30) {
            iconClass = 'battery-medium';
            statusText = 'Normal';
        } else if (displayLevel >= 15) {
            iconClass = 'battery-low';
            statusText = 'Low';
        } else {
            iconClass = 'battery-critical';
            statusText = 'Critical!';
        }
    }

    updates.push(() => batteryIcon.addClass(iconClass));
    updates.push(() => $('.battery-status').text(statusText));
    updates.push(() => $('#toggle-charger').text(buttonText));

    // Execute all DOM updates in a single animation frame for better performance
    requestAnimationFrame(() => {
        updates.forEach(update => update());
    });
}

// Enhanced phone closing function with error handling
function closePhone() {
    if (!laptopOpen) {
        safeLogDebug('Phone already closed');
        return;
    }
    
    // Send close notification to client  
    $.post('https://qb-hackerjob/closePhone', JSON.stringify({}), function(response) {
        safeLogDebug('Phone close notification sent successfully');
    }).fail(function(error) {
        safeLogError('Failed to notify client of phone close: ' + error.message);
    });

    safeLogInfo('Closing phone');
    
    try {
        const phoneContainer = $('#phone-container');
        if (phoneContainer.length > 0) {
            phoneContainer.removeClass('visible');
        }

        setTimeout(() => {
            try {
                resetUI();
                
                // Safe server notification
                safePost('https://qb-hackerjob/closeLaptop', 
                    {},
                    function(response) {
                        safeLogDebug('Laptop close notification sent successfully');
                    },
                    function(error) {
                        safeLogError('Failed to notify server of laptop close: ' + error.message);
                    }
                );
                
                safeLogInfo('Laptop closed successfully');
            } catch (err) {
                safeLogError('Error during laptop close cleanup: ' + err.message);
            }
        }, 500);
    } catch (err) {
        safeLogError('Error in closePhone function: ' + err.message);
        // Force reset UI as fallback
        try {
            resetUI();
        } catch (e) {
            safeLogError('Critical error during close fallback: ' + e.message);
        }
    }
}

// Open an app screen
function openApp(appName) {
    phoneLastUsed = Date.now();
    
    // Hide home screen
    $('#home-screen').addClass('hidden');
    
    // Close any currently open app
    if (activeAppScreen) {
        $(`#${activeAppScreen}`).addClass('hidden');
    }

    // Determine which app to open
    let appScreen;
    let initialTab = null;

    switch (appName) {
        case 'plate-lookup':
            appScreen = 'plate-lookup-app';
            initialTab = 'search'; // Default to search tab
            break;
        case 'phone-tracker':
            appScreen = 'phone-tracker-app';
            initialTab = 'phone-search';
            break;
        case 'radio-decrypt':
            appScreen = 'radio-decrypt-app';
            initialTab = 'radio-search';
            break;
        default:
            console.error('Unknown app:', appName);
            return;
    }

    // Open the app screen
    activeAppScreen = appScreen;
    $(`#${appScreen}`).removeClass('hidden');

    // Set initial active tab if specified
    if (initialTab) {
        // Deactivate all tabs and content first
        $(`#${appScreen}`).find('.tab-item').removeClass('active');
        $(`#${appScreen}`).find('.tab-content').removeClass('active');

        // Activate the specified initial tab and content
        $(`#${appScreen}`).find(`.tab-item[data-tab="${initialTab}"]`).addClass('active');
        $(`#${appScreen}`).find(`#${initialTab}-tab`).addClass('active');
    }
}

// Close an app screen and return to home
function closeApp(appScreenId) {
    $(`#${appScreenId}`).addClass('hidden');
    activeAppScreen = null;
    $('#home-screen').removeClass('hidden');
    phoneLastUsed = Date.now();
}

// Go back to home screen
function goToHome() {
    if (activeAppScreen) {
        $(`#${activeAppScreen}`).addClass('hidden');
        activeAppScreen = null;
    }
    $('#home-screen').removeClass('hidden');
    phoneLastUsed = Date.now();
}

// Update the clock in the status bar
function updateClock() {
    const now = new Date();
    const hours = now.getHours().toString().padStart(2, '0');
    const minutes = now.getMinutes().toString().padStart(2, '0');
    $('#clock').text(`${hours}:${minutes}`);
}

// Update greeting based on time of day
function updateGreeting() {
    const now = new Date();
    const hour = now.getHours();
    let greeting;
    
    if (hour < 12) {
        greeting = 'Good morning';
    } else if (hour < 17) {
        greeting = 'Good afternoon';
    } else {
        greeting = 'Good evening';
    }
    
    $('.greeting').text(greeting);
}

// Play sound effects - Empty function that does nothing
function playSound(sound) {
    // Function is intentionally empty to disable all sounds
    // Keeping the function to avoid breaking existing code that calls it
    return;
}

// Vehicle Functions

// Enhanced plate search function with error handling
function searchPlate(plate) {
    safeLogDebug('Starting plate search for: ' + plate);
    
    // Validate input
    if (!plate || typeof plate !== 'string' || plate.trim() === '') {
        safeLogError('Invalid plate provided to searchPlate');
        return;
    }
    
    const trimmedPlate = plate.trim().toUpperCase();
    
    try {
        // Show loading animation
        const vehicleInfoElement = $('#vehicle-info');
        if (vehicleInfoElement.length === 0) {
            safeLogError('Vehicle info element not found');
            return;
        }
        
        vehicleInfoElement.html('<div class="loading-text">Searching database for plate ' + trimmedPlate + '...</div>');
        
        // Switch to results tab
        switchToResultsTab();
        
        // Call the client callback
        $.post('https://qb-hackerjob/performPlateLookup', JSON.stringify({
            plate: trimmedPlate
        }), function(response) {
            safeLogDebug('Plate lookup response received:', response);
            
            if (response && response.success) {
                safeLogInfo('Plate lookup successful for: ' + trimmedPlate);
                // Results will be updated via the updateVehicleData message
            } else {
                safeLogError('Plate lookup failed: ' + (response ? response.message : 'Unknown error'));
                vehicleInfoElement.html('<div class="error-text">Lookup failed: ' + (response ? response.message : 'Database error') + '</div>');
            }
        }).fail(function(error) {
            safeLogError('Plate lookup request failed: ' + error.message);
            vehicleInfoElement.html('<div class="error-text">Connection error. Please try again.</div>');
        });
        
        // Change to results tab
        const resultsTab = $('#plate-lookup-app .tab[data-tab="results"]');
        if (resultsTab.length > 0) {
            resultsTab.click();
        } else {
            safeLogError('Results tab not found');
        }
        
        // Safe server call
        safePost('https://qb-hackerjob/lookupPlate', 
            { plate: trimmedPlate },
            function(response) {
                try {
                    if (!response || typeof response !== 'object') {
                        throw new Error('Invalid response format');
                    }
                    
                    if (!response.success) {
                        const errorMessage = response.message || 'Could not retrieve data';
                        vehicleInfoElement.html('<div class="no-results">Error: ' + errorMessage + '</div>');
                        safeLogError('Plate lookup failed: ' + errorMessage);
                    } else {
                        safeLogInfo('Plate lookup successful for: ' + trimmedPlate);
                        // Success handling will be done by the message handler
                    }
                } catch (err) {
                    safeLogError('Error processing plate lookup response: ' + err.message);
                    vehicleInfoElement.html('<div class="no-results">Error: Failed to process response</div>');
                }
            },
            function(error) {
                safeLogError('Plate lookup request failed: ' + error.message);
                vehicleInfoElement.html('<div class="no-results">Error: Connection failed - please try again</div>');
            }
        );
    } catch (err) {
        safeLogError('Error in searchPlate function: ' + err.message);
    }
}

// Update the list of nearby vehicles
function updateNearbyVehicles() {
    $('#nearby-vehicles').html('<div class="loading-text">Scanning for vehicles...</div>');

    // Call the server to get nearby vehicles
    $.post('https://qb-hackerjob/getNearbyVehicles', JSON.stringify({}), function(response) {
        if (response.success && response.vehicles && response.vehicles.length > 0) {
            nearbyVehicles = response.vehicles;
            displayNearbyVehicles();
        } else {
            $('#nearby-vehicles').html('<div class="no-results">No vehicles detected nearby.</div>');
        }
    });
}

// Function to display the list of nearby vehicles
function displayNearbyVehicles() {
    console.log('Displaying nearby vehicles:', nearbyVehicles);
    const container = $('#nearby-vehicles');
    container.empty();

    if (!nearbyVehicles || nearbyVehicles.length === 0) {
        container.html('<div class="no-results">No vehicles detected nearby.</div>');
        return;
    }

    // Add info note at the top
    container.append('<div class="info-note">Quick scan results. This shows only basic vehicle information. Hack a vehicle to access full registration details.</div>');

    // Create vehicle list
    nearbyVehicles.forEach(function(vehicle, i) {
        console.log(`Creating vehicle item ${i}: ${vehicle.plate} - ${vehicle.make} ${vehicle.model}`);

        // Create vehicle item with data attribute for index
        const vehicleHtml = `
            <div class="nearby-vehicle-item" data-vehicle-index="${i}">
                <div class="vehicle-info">
                    <div class="vehicle-plate">${vehicle.plate}</div>
                    <div class="vehicle-make-model">${vehicle.make} ${vehicle.model}</div>
                    <div class="vehicle-details">
                        <span>Class: ${vehicle.class}</span>
                        <span> • </span>
                        <span>~${vehicle.distance}m</span>
                    </div>
                </div>
                <button class="lookup-button" data-vehicle-index="${i}">Hack</button>
            </div>
        `;

        container.append(vehicleHtml);
    });

    // Add event handlers using event delegation
    container.off('click', '.nearby-vehicle-item');
    container.off('click', '.lookup-button');

    // Attach click event to parent container for better event delegation
    container.on('click', '.nearby-vehicle-item', function(e) {
        if ($(e.target).hasClass('lookup-button')) {
            // Button click is handled separately
            return;
        }
        const vehicleIndex = parseInt($(this).attr('data-vehicle-index'));
        console.log('Vehicle item clicked, index:', vehicleIndex);
        searchNearbyVehicle(vehicleIndex);
    });

    container.on('click', '.lookup-button', function(e) {
        e.stopPropagation(); // Prevent triggering the parent click
        const vehicleIndex = parseInt($(this).attr('data-vehicle-index'));
        console.log('Hack button clicked, index:', vehicleIndex);
        searchNearbyVehicle(vehicleIndex);
    });
}

// Function to search a nearby vehicle by index
function searchNearbyVehicle(index) {
    console.log('Attempting to look up vehicle at index: ' + index);
    console.log('Vehicle data:', nearbyVehicles[index]);

    // Show loading indicator
    $('#vehicle-info').html('<div class="loading-text">Accessing vehicle database...</div>');

    // Switch to results tab
    $('#plate-lookup-app .tab[data-tab="results"]').click();

    // Send index to backend to perform lookup
    $.post('https://qb-hackerjob/lookupVehicleByIndex', JSON.stringify({
        index: index
    }), function(response) {
        console.log('Lookup response:', response);
        if (!response.success) {
            $('#vehicle-info').html('<div class="no-results">Failed to lookup vehicle. Try again.</div>');
        }
    });
}

// Process and display vehicle data
function displayVehicleData(data) {
    if (!data) {
        $('#vehicle-info').html('<div class="no-results">No vehicle data available.</div>');
        return;
    }

    console.log('Vehicle data:', data);

    // Create a custom HTML structure with vehicle actions
    const registrationStatus = data.ownertype === 'player' ? 'Registered' : 'Not Registered';
    const ownerDisplay = data.owner ? data.owner : 'Unknown';

    const vehicleHtml = `
    <div class="info-card">
        <div class="info-header">
            <h2 class="vehicle-title">Vehicle Information</h2>
            <div class="info-plate">${data.plate}</div>
        </div>
        <div class="info-content">
            <div class="info-row">
                <div class="info-label">Registration:</div>
                <div class="info-value">${registrationStatus}</div>
            </div>
            <div class="info-row">
                <div class="info-label">Owner:</div>
                <div class="info-value">${ownerDisplay}</div>
            </div>
            <div class="info-row">
                <div class="info-label">Make/Model:</div>
                <div class="info-value">${data.make} ${data.model}</div>
            </div>
            <div class="info-row">
                <div class="info-label">Class:</div>
                <div class="info-value">${data.class || 'Unknown'}</div>
            </div>
            <div class="info-row">
                <div class="info-label">VIN:</div>
                <div class="info-value">${data.vin || 'Unknown'}</div>
            </div>

            <div class="info-flags">
                ${data.flags && data.flags.stolen ? '<div class="flag flag-stolen">STOLEN</div>' : ''}
                ${data.flags && data.flags.police ? '<div class="flag flag-police">LAW ENFORCEMENT</div>' : ''}
                ${data.flags && data.flags.emergency ? '<div class="flag flag-registered">EMERGENCY SERVICES</div>' : ''}
                ${data.flags && data.flags.flagged ? '<div class="flag flag-flagged">FLAGGED</div>' : ''}
                ${data.flags && data.flags.rental ? '<div class="flag flag-registered">RENTAL</div>' : ''}
                ${!data.flags || (!data.flags.stolen && !data.flags.police && !data.flags.emergency && !data.flags.flagged && !data.flags.rental) ? '<div class="flag flag-registered">REGISTERED</div>' : ''}
            </div>

            <div class="vehicle-actions">
                <button class="action-btn vehicle-action" data-action="lock" data-plate="${data.plate}">
                    <i class="fas">🔒</i>
                    <span>Lock</span>
                </button>
                <button class="action-btn vehicle-action" data-action="unlock" data-plate="${data.plate}">
                    <i class="fas">🔓</i>
                    <span>Unlock</span>
                </button>
                <button class="action-btn vehicle-action" data-action="engine" data-plate="${data.plate}">
                    <i class="fas">⚙️</i>
                    <span>Toggle Engine</span>
                </button>
                <button class="action-btn vehicle-action" data-action="track" data-plate="${data.plate}">
                    <i class="fas">📍</i>
                    <span>Track GPS</span>
                </button>
                <button class="action-btn vehicle-action danger-action" data-action="disable_brakes" data-plate="${data.plate}">
                    <i class="fas">🛑</i>
                    <span>Disable Brakes</span>
                </button>
                <button class="action-btn vehicle-action danger-action" data-action="accelerate" data-plate="${data.plate}">
                    <i class="fas">⚡</i>
                    <span>Force Accelerate</span>
                </button>
            </div>
        </div>
    </div>
    `;

    // Display the vehicle information
    $('#vehicle-info').html(vehicleHtml);

    // Add event listeners to action buttons
    $('.vehicle-action').on('click', function() {
        const action = $(this).data('action');
        const plate = $(this).data('plate');
        performVehicleAction(action, plate);
    });

    // Switch to results tab
    $('#plate-lookup-app .tab[data-tab="results"]').click();
}

// Function to show the action overlay
function showActionOverlay(message) {
    // Create overlay if it doesn't exist
    if ($('.action-overlay').length === 0) {
        $('body').append(`<div class="action-overlay"><div class="loading-text">${message}</div></div>`);
    } else {
        $('.action-overlay .loading-text').text(message);
    }
}

// Function to hide the action overlay
function hideActionOverlay() {
    $('.action-overlay').remove();
}

// Function to show loading line
function showLoadingLine() {
    // Create loading line if it doesn't exist
    if ($('.loading-line').length === 0) {
        $('body').append(`
            <div class="loading-line">
                <div class="loading-progress"></div>
            </div>
        `);
    }
    $('.loading-line').show();
}

// Function to hide loading line
function hideLoadingLine() {
    $('.loading-line').hide();
}

// Function to perform actions on vehicles
function performVehicleAction(action, plate) {
    console.log(`Performing ${action} on vehicle ${plate}`);

    // For high-risk actions, require captcha first
    if (action === 'disable_brakes' || action === 'accelerate' || action === 'track') {
        // Show captcha challenge instead of directly performing action
        showCaptchaChallenge(action, plate);
        return;
    }

    // Regular actions continue as normal
    // Show loading line
    showLoadingLine();
    
    // Normal action handling
    $.post('https://qb-hackerjob/performVehicleAction', JSON.stringify({
        action: action,
        plate: plate
    }), function(response) {
        hideLoadingLine();
        if (response.success) {
            showActionSuccess(action, plate);
        } else {
            showActionFailed(action, plate);
        }
    }).fail(function() {
        hideLoadingLine();
        showActionFailed(action, plate);
    });
}

// Function to show captcha challenge
function showCaptchaChallenge(action, plate) {
    // Generate random captcha code (5-6 letters only)
    const length = Math.floor(Math.random() * 2) + 5; // 5-6 letters
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    let captchaCode = '';

    for (let i = 0; i < length; i++) {
        captchaCode += chars.charAt(Math.floor(Math.random() * chars.length));
    }

    // Calculate time limit based on action (3-5 seconds)
    let timeLimit = 5;
    if (action === 'disable_brakes') {
        timeLimit = 3; // Harder
    } else if (action === 'accelerate') {
        timeLimit = 4; // Medium
    } else if (action === 'track') {
        timeLimit = 5; // Easier
    }

    // Create overlay with captcha challenge
    const overlay = $(`
        <div class="captcha-overlay">
            <div class="captcha-container">
                <div class="captcha-header">SECURITY VERIFICATION REQUIRED</div>
                <div class="captcha-instruction">Type the following code within ${timeLimit} seconds:</div>
                <div class="captcha-code">${captchaCode}</div>
                <input type="text" class="captcha-input" placeholder="Type code here..." autofocus>
                <div class="captcha-timer">Time remaining: <span class="timer-value">${timeLimit}</span>s</div>
                <div class="captcha-buttons">
                    <button class="captcha-submit">Submit</button>
                    <button class="captcha-cancel">Cancel</button>
                </div>
            </div>
        </div>
    `);

    // Add overlay to body
    $('body').append(overlay);

    // Focus input
    setTimeout(() => {
        $('.captcha-input').focus();
    }, 10);

    // Start timer
    let timeRemaining = timeLimit;
    const timerInterval = setInterval(() => {
        timeRemaining--;
        $('.timer-value').text(timeRemaining);

        if (timeRemaining <= 0) {
            clearInterval(timerInterval);
            captchaFailed(action, plate);
        }
    }, 1000);

    // Handle submit button
    $('.captcha-submit').on('click', () => {
        const input = $('.captcha-input').val();
        if (input === captchaCode) {
            clearInterval(timerInterval);
            captchaSuccess(action, plate);
        } else {
            clearInterval(timerInterval);
            captchaFailed(action, plate);
        }
    });

    // Handle cancel button
    $('.captcha-cancel').on('click', () => {
        clearInterval(timerInterval);
        $('.captcha-overlay').remove();
    });

    // Handle Enter key
    $('.captcha-input').on('keyup', (e) => {
        if (e.keyCode === 13) { // Enter key
            const input = $('.captcha-input').val();
            if (input === captchaCode) {
                clearInterval(timerInterval);
                captchaSuccess(action, plate);
            } else {
                clearInterval(timerInterval);
                captchaFailed(action, plate);
            }
        }
    });

    // Auto-check input as user types (for perfect match)
    $('.captcha-input').on('input', function() {
        const input = $(this).val();
        if (input === captchaCode) {
            clearInterval(timerInterval);
            captchaSuccess(action, plate);
        }
    });
}

// Function when captcha is successful
function captchaSuccess(action, plate) {
    // Remove overlay
    $('.captcha-overlay').remove();

    // Show success message
    const notification = $(`<div class="action-success">Verification successful - Access granted</div>`);
    $('body').append(notification);
    setTimeout(() => {
        notification.remove();
    }, 1500);

    // Proceed with the action
    setTimeout(() => {
        // Show action overlay
        showActionOverlay(`Attempting to ${action.replace('_', ' ')} vehicle...`);

        // Special handling for tracking function
        if (action === 'track') {
            $.post('https://qb-hackerjob/trackVehicle', JSON.stringify({
                plate: plate
            }), function(response) {
                hideActionOverlay();
                if (response.success) {
                    showActionSuccess(action, plate);
                } else {
                    showActionFailed(action, plate);
                }
            });
            return;
        }

        // Normal action handling
        $.post('https://qb-hackerjob/performVehicleAction', JSON.stringify({
            action: action,
            plate: plate
        }), function(response) {
            hideActionOverlay();
            if (response.success) {
                showActionSuccess(action, plate);
            } else {
                showActionFailed(action, plate);
            }
        });

        // Safety timeout
        setTimeout(() => {
            hideActionOverlay();
        }, 5000);
    }, 1000);
}

// Function when captcha fails
function captchaFailed(action, plate) {
    // Remove overlay
    $('.captcha-overlay').remove();

    // Show failure message
    const notification = $(`<div class="action-failed">Verification failed - Security lockout activated</div>`);
    $('body').append(notification);
    setTimeout(() => {
        notification.remove();
    }, 3000);
}

// Function to show success notification for actions
function showActionSuccess(action, plate) {
    // Create message based on action
    let message = '';
    switch(action) {
        case 'lock':
            message = `Vehicle ${plate} successfully locked remotely`;
            break;
        case 'unlock':
            message = `Vehicle ${plate} successfully unlocked remotely`;
            break;
        case 'engine':
            message = `Remote engine control established for ${plate}`;
            break;
        case 'disable_brakes':
            message = `${plate}: Brake system permanently compromised - repair required`;
            break;
        case 'accelerate':
            message = `${plate}: Remote acceleration override in progress`;
            break;
        case 'track':
            message = `GPS tracker activated for vehicle ${plate}`;
            break;
        default:
            message = `Action ${action} executed successfully on ${plate}`;
    }

    // Show notification
    const notification = $(`<div class="action-success">${message}</div>`);
    $('body').append(notification);

    // Remove after animation
    setTimeout(() => {
        notification.remove();
    }, 3000);
}

// Function to show failed notification for actions
function showActionFailed(action, plate) {
    // Create message based on action
    let message = '';
    switch(action) {
        case 'lock':
            message = `Failed to lock vehicle ${plate} - out of range or system error`;
            break;
        case 'unlock':
            message = `Failed to unlock vehicle ${plate} - out of range or system error`;
            break;
        case 'engine':
            message = `Engine control failed for ${plate} - vehicle security active`;
            break;
        case 'disable_brakes':
            message = `${plate}: Failed to compromise brake system - advanced security detected`;
            break;
        case 'accelerate':
            message = `${plate}: Remote acceleration failed - engine protection activated`;
            break;
        case 'track':
            message = `GPS tracking failed for vehicle ${plate} - tracker item required`;
            break;
        default:
            message = `Action ${action} failed on ${plate} - system error`;
    }

    // Show notification
    const notification = $(`<div class="action-failed">${message}</div>`);
    $('body').append(notification);

    // Remove after animation
    setTimeout(() => {
        notification.remove();
    }, 3000);
}

// Phone & Radio Functions
function trackPhone(phone) {
    $('#phone-info').html('<div class="loading-text">Triangulating phone signal...</div>');
    $('#phone-tracker-app .tab[data-tab="phone-results"]').click();

    // This would connect to the real tracking function in the future
    // For now, just simulate a response
    setTimeout(() => {
        $('#phone-info').html('<div class="info-card"><div class="info-header"><h2 class="vehicle-title">Phone Tracking</h2><div class="info-plate">' + phone + '</div></div><div class="info-content"><div class="info-row"><div class="info-label">Status:</div><div class="info-value">Feature not implemented yet</div></div></div></div>');
    }, 3000);
}

function decryptRadio(frequency) {
    $('#radio-info').html('<div class="loading-text">Attempting to decrypt radio signals...</div>');
    $('#radio-decrypt-app .tab[data-tab="radio-results"]').click();

    // This would connect to the real decryption function in the future
    // For now, just simulate a response
    setTimeout(() => {
        $('#radio-info').html('<div class="info-card"><div class="info-header"><h2 class="vehicle-title">Radio Decryption</h2><div class="info-plate">' + frequency + ' MHz</div></div><div class="info-content"><div class="info-row"><div class="info-label">Status:</div><div class="info-value">Feature not implemented yet</div></div></div></div>');
    }, 3000);
}

// Enhanced NUI Message Handler with comprehensive error handling
window.addEventListener('message', function(event) {
    try {
        const data = event.data;
        
        if (!data || typeof data !== 'object') {
            safeLogError('Invalid message data received');
            return;
        }
        
        const action = data.action || data.type;
        if (!action) {
            safeLogError('No action specified in message data');
            return;
        }
        
        safeLogDebug('Received message with action: ' + action);
        
        try {
            switch (action) {
                case 'openPhone':
                case 'openLaptop': // Keep backward compatibility
                    // Safe data extraction
                    currentLevel = (typeof data.level === 'number' && data.level > 0) ? data.level : 1;
                    currentXP = (typeof data.xp === 'number' && data.xp >= 0) ? data.xp : 0;
                    nextLevelXP = (typeof data.nextLevelXP === 'number' && data.nextLevelXP > 0) ? data.nextLevelXP : 100;
                    currentLevelName = (typeof data.levelName === 'string' && data.levelName.length > 0) ? data.levelName : "Script Kiddie";
                    
                    openPhone(data);
                    break;
                    
                case 'closePhone':
                case 'closeLaptop': // Keep backward compatibility
                    closePhone();
                    break;
                    
                case 'updateVehicleData':
                    if (data.data) {
                        displayVehicleData(data.data);
                    } else {
                        safeLogError('No vehicle data provided in updateVehicleData message');
                    }
                    break;
                    
                case 'updateNearbyVehicles':
                    // ### DISABLED NEARBY VEHICLES ###
                    safeLogInfo('Received updateNearbyVehicles event - DISABLED');
                    try {
                        const nearbyElement = $('#nearby-vehicles');
                        if (nearbyElement.length > 0) {
                            nearbyElement.html('<div class="info-note">Nearby vehicle scanning is disabled. Use the Search tab.</div>');
                        }
                        nearbyVehicles = [];
                    } catch (err) {
                        safeLogError('Error updating nearby vehicles UI: ' + err.message);
                    }
                    break;
                    
                case 'updateBattery':
                    try {
                        const level = (typeof data.level === 'number' && data.level >= 0 && data.level <= 100) ? data.level : 100;
                        const charging = Boolean(data.charging);
                        
                        // Force create battery indicator if it doesn't exist
                        if ($('#battery-indicator').length === 0 || $('#battery-menu').length === 0) {
                            safeLogDebug('Creating missing battery elements from message handler');
                            createBatteryIndicator();
                        }
                        
                        updateBatteryDisplay(level, charging);
                    } catch (err) {
                        safeLogError('Error updating battery display: ' + err.message);
                    }
                    break;
                    
                case 'updateHackerStats':
                    try {
                        const level = (typeof data.level === 'number' && data.level > 0) ? data.level : 1;
                        const xp = (typeof data.xp === 'number' && data.xp >= 0) ? data.xp : 0;
                        const nextXP = (typeof data.nextLevelXP === 'number' && data.nextLevelXP > 0) ? data.nextLevelXP : 100;
                        const levelName = (typeof data.levelName === 'string' && data.levelName.length > 0) ? data.levelName : "Script Kiddie";
                        
                        safeLogDebug('Updating hacker stats - Level: ' + level + ', XP: ' + xp + ', NextXP: ' + nextXP + ', Name: ' + levelName);
                        
                        // Update global vars
                        currentLevel = level;
                        currentXP = xp;
                        nextLevelXP = nextXP;
                        currentLevelName = levelName;
                        
                        // Update display
                        updateHackerStatsDisplay(level, xp, nextXP, levelName);
                        
                        // Force refresh with delay
                        setTimeout(() => {
                            try {
                                updateHackerStatsDisplay(level, xp, nextXP, levelName);
                            } catch (err) {
                                safeLogError('Error in delayed stats update: ' + err.message);
                            }
                        }, 50);
                    } catch (err) {
                        safeLogError('Error updating hacker stats: ' + err.message);
                    }
                    break;
                    
                case 'phoneTrackResult':
                    safeLogDebug('Phone track result received (not implemented)');
                    break;
                    
                case 'radioDecryptResult':
                    safeLogDebug('Radio decrypt result received (not implemented)');
                    break;
                    
                default:
                    safeLogError('Unknown message action: ' + action);
                    break;
            }
        } catch (err) {
            safeLogError('Error handling message action ' + action + ': ' + err.message);
        }
    } catch (err) {
        safeLogError('Critical error in message handler: ' + err.message);
    }
});

// Optimized hacker stats display update with batched DOM operations
function updateHackerStatsDisplay(level, xp, nextXP, levelName) {
    // Update global variables
    currentLevel = level;
    currentXP = xp;
    nextLevelXP = nextXP;
    currentLevelName = levelName;

    // Cache DOM elements
    const levelElement = $('#hacker-level-name');
    const xpElement = $('#hacker-xp-progress');

    // Prepare display values
    const displayLevelName = levelName || `Level ${level}`;
    const displayNextXP = (typeof nextXP === 'number' && nextXP > 0) ? nextXP : '?';
    const displayXPText = `XP: ${xp} / ${displayNextXP}`;

    // Batch DOM updates in a single animation frame
    requestAnimationFrame(() => {
        if (levelElement.length > 0) {
            levelElement.text(displayLevelName);
        } else {
            console.warn("Could not find #hacker-level-name element to update.");
        }

        if (xpElement.length > 0) {
            xpElement.text(displayXPText);
        } else {
            console.warn("Could not find #hacker-xp-progress element to update.");
        }
    });
}

// Add styles for captcha at the end of the file
window.addEventListener('DOMContentLoaded', function() {
    const styleElement = document.createElement('style');
    styleElement.textContent = `
        .captcha-overlay {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background-color: rgba(0, 0, 0, 0.85);
            z-index: 9999;
            display: flex;
            justify-content: center;
            align-items: center;
        }

        .captcha-container {
            background-color: #0a1a2a;
            border: 2px solid #0f5;
            border-radius: 5px;
            padding: 20px;
            width: 80%;
            max-width: 500px;
            text-align: center;
            box-shadow: 0 0 20px rgba(0, 255, 85, 0.5);
        }

        .captcha-header {
            font-size: 18px;
            font-weight: bold;
            margin-bottom: 15px;
            color: #0f5;
            text-shadow: 0 0 5px rgba(0, 255, 85, 0.7);
        }

        .captcha-instruction {
            font-size: 14px;
            margin-bottom: 15px;
            color: #fff;
        }

        .captcha-code {
            font-family: 'Courier New', monospace;
            font-size: 24px;
            font-weight: bold;
            letter-spacing: 2px;
            margin: 20px 0;
            padding: 10px;
            background-color: #0f1319;
            border: 1px solid #0f5;
            color: #0f5;
            text-shadow: 0 0 5px rgba(0, 255, 85, 0.7);
        }

        .captcha-input {
            width: 100%;
            padding: 10px;
            margin-bottom: 15px;
            background-color: #0a0a0a;
            border: 1px solid #0f5;
            color: #fff;
            text-align: center;
            font-size: 18px;
            outline: none;
        }

        .captcha-input:focus {
            box-shadow: 0 0 10px rgba(0, 255, 85, 0.5);
        }

        .captcha-timer {
            margin-bottom: 15px;
            color: #ff5050;
            font-weight: bold;
        }

        .captcha-buttons {
            display: flex;
            justify-content: space-between;
        }

        .captcha-buttons button {
            padding: 8px 15px;
            border: none;
            border-radius: 3px;
            cursor: pointer;
            font-weight: bold;
            flex: 1;
            margin: 0 5px;
        }

        .captcha-submit {
            background-color: #0f5;
            color: #000;
        }

        .captcha-cancel {
            background-color: #555;
            color: #fff;
        }

        .captcha-submit:hover {
            background-color: #0c3;
        }

        .captcha-cancel:hover {
            background-color: #777;
        }
    `;
    document.head.appendChild(styleElement);
});

// Touch gesture handling for phone interface
function setupTouchGestures() {
    const phoneContainer = document.getElementById('phone-container');
    let startY = 0;
    let currentY = 0;
    let isDragging = false;

    // Touch events for swipe gestures
    phoneContainer.addEventListener('touchstart', touchStart, { passive: true });
    phoneContainer.addEventListener('touchmove', touchMove, { passive: true });
    phoneContainer.addEventListener('touchend', touchEnd, { passive: true });

    function touchStart(e) {
        startY = e.touches[0].clientY;
        isDragging = true;
    }

    function touchMove(e) {
        if (!isDragging) return;
        currentY = e.touches[0].clientY;
    }

    function touchEnd(e) {
        if (!isDragging) return;
        isDragging = false;

        const deltaY = currentY - startY;
        const threshold = 100;

        // Swipe down from top to close phone (if no active app)
        if (deltaY > threshold && startY < 100 && !activeAppScreen) {
            closePhone();
        }
    }
}
