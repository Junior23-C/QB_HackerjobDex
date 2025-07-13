// NUI Variables
let laptopOpen = false;
let activeAppWindow = null;
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

// DOM Ready
$(document).ready(function() {
    // Initialize
    resetUI();
    setupEventHandlers();
    setupDragFunctionality();
    updateClock();

    // ### DISABLE NEARBY TAB VISUALLY ###
    // Hide the nearby tab and its content pane permanently
    $('#plate-lookup-app .tab[data-tab="nearby"]').hide();
    $('#nearby-tab').hide();
    // Ensure search is the default active tab (might be redundant with openApp logic but safe)
    $('#plate-lookup-app .tab[data-tab="search"]').addClass('active');
    $('#search-tab').addClass('active');
    // ##################################

    // Clock updater
    setInterval(updateClock, 60000); // Update clock every minute
});

// Setup all event handlers
function setupEventHandlers() {
    // Desktop icon click handler
    $('.desktop-icon').on('click', function() {
        const appName = $(this).data('app');
        openApp(appName);
    });

    // Window controls
    $('.window-close').on('click', function() {
        const appWindow = $(this).closest('.app-window');
        closeApp(appWindow.attr('id'));
    });

    $('.window-minimize').on('click', function() {
        const appWindow = $(this).closest('.app-window');
        minimizeApp(appWindow.attr('id'));
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

    // Plate Lookup
    $('#search-plate').on('click', function() {
        const plate = $('#plate-input').val().trim();
        if (plate.length > 0) {
            searchPlate(plate);
        }
    });

    $('#plate-input').on('keyup', function(e) {
        if (e.keyCode === 13) {
            const plate = $(this).val().trim();
            if (plate.length > 0) {
                searchPlate(plate);
            }
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

    // On escape key, close the laptop
    $(document).on('keyup', function(e) {
        if (e.keyCode === 27) {
            closeLaptop();
        }
    });
}

// Reset UI state
function resetUI() {
    laptopOpen = false;
    activeAppWindow = null;
    $('#laptop-container').removeClass('visible').addClass('hidden');
    $('.app-window').addClass('hidden');
    $('.boot-progress-bar').css('width', '0%');
    $('#desktop').addClass('hidden');
    $('#boot-screen').removeClass('hidden');
    batteryLevel = 100;
    isCharging = false;
    currentLevel = 1;
    currentXP = 0;
    nextLevelXP = 100;
    currentLevelName = "Script Kiddie";
    updateHackerStatsDisplay(); // Reset display
}

// Open the laptop
function openLaptop(data) {
    if (laptopOpen) return;

    console.log('Opening laptop with data:', data);

    // Process incoming data if provided
    if (data) {
        soundEnabled = false; // Force disable sound
        useAnimations = data.animations !== undefined ? data.animations : true;
        darkTheme = data.theme === 'dark'; // Assuming theme comes from Lua now
        batteryLevel = data.batteryLevel !== undefined ? data.batteryLevel : 100;
        isCharging = data.charging !== undefined ? data.charging : false;
        // Store initial hacker stats from Lua
        currentLevel = data.level || 1;
        currentXP = data.xp || 0;
        nextLevelXP = data.nextLevelXP || 100;
        currentLevelName = data.levelName || "Script Kiddie";
    }

    laptopOpen = true;

    // Show the laptop container
    $('#laptop-container').removeClass('hidden').addClass('visible');

    // Force clear any existing battery elements to prevent duplicates
    $('#battery-indicator, #battery-menu').remove();

    // Create battery indicator
    createBatteryIndicator();

    // Update battery display
    updateBatteryDisplay(batteryLevel, isCharging);

    // Update hacker stats display (initial)
    updateHackerStatsDisplay(currentLevel, currentXP, nextLevelXP, currentLevelName);

    // Skip animations if disabled
    if (!useAnimations) {
        $('#boot-screen').addClass('hidden');
        $('#desktop').removeClass('hidden');
        return;
    }

    // Reset boot screen
    $('#boot-screen').removeClass('hidden');
    $('.boot-progress-bar').css('width', '0%');
    $('.boot-text').text('INITIALIZING SECURE SHELL...');

    // Start boot sequence
    const bootMessages = [
        'INITIALIZING SECURE SHELL...',
        'ESTABLISHING ENCRYPTED CONNECTION...',
        'BYPASSING SECURITY PROTOCOLS...',
        'LOADING CORE MODULES...',
        'ACTIVATING NETWORK INTERFACES...',
        'SYSTEM READY'
    ];

    let messageIndex = 0;
    let progressIncrement = 100 / (bootMessages.length - 1);

    const bootSequence = setInterval(() => {
        // Update boot message
        $('.boot-text').text(bootMessages[messageIndex]);

        // Increment progress bar
        let currentProgress = progressIncrement * messageIndex;
        $('.boot-progress-bar').css('width', `${currentProgress}%`);

        messageIndex++;

        // When boot sequence is complete
        if (messageIndex >= bootMessages.length) {
            clearInterval(bootSequence);

            // Finish progress bar animation
            $('.boot-progress-bar').css('width', '100%');

            // Delay slightly before showing desktop
            setTimeout(() => {
                // Hide boot screen and show desktop
                $('#boot-screen').addClass('hidden');
                $('#desktop').removeClass('hidden');
            }, 500);
        }
    }, 600);
}

// Create battery indicator for taskbar
function createBatteryIndicator() {
    console.log('Creating battery indicator');

    // Remove if it already exists
    $('#battery-indicator, #battery-menu').remove();

    // Add battery element to taskbar
    $('.taskbar').append(`
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

// Update battery display - enhanced version
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

    // Update percentage text
    $('.battery-percentage').text(`${displayLevel}%`);
    $('.battery-percentage-large').text(`${displayLevel}%`);

    // Update battery meter
    $('.battery-meter-fill').css('width', `${displayLevel}%`);

    // Update battery icon class based on level
    const batteryIcon = $('.battery-icon');
    batteryIcon.removeClass('battery-high battery-medium battery-low battery-critical battery-charging');

    if (isCharging) {
        batteryIcon.addClass('battery-charging');
        $('.battery-status').text('Charging');
        $('#toggle-charger').text('Disconnect Charger');
    } else {
        $('#toggle-charger').text('Connect Charger');

        if (displayLevel >= 60) {
            batteryIcon.addClass('battery-high');
            $('.battery-status').text('Normal');
        } else if (displayLevel >= 30) {
            batteryIcon.addClass('battery-medium');
            $('.battery-status').text('Normal');
        } else if (displayLevel >= 15) {
            batteryIcon.addClass('battery-low');
            $('.battery-status').text('Low');
        } else {
            batteryIcon.addClass('battery-critical');
            $('.battery-status').text('Critical!');
        }
    }
}

// Close laptop UI
function closeLaptop() {
    if (!laptopOpen) return;

    $('#laptop-container').removeClass('visible');

    setTimeout(() => {
        resetUI();
        $.post('https://qb-hackerjob/closeLaptop', JSON.stringify({}));
    }, 500);
}

// Open an app window
function openApp(appName) {
    // Close any currently open app
    if (activeAppWindow) {
        $(`#${activeAppWindow}`).addClass('hidden');
    }

    // Determine which app to open
    let appWindow;
    let initialTab = null;

    switch (appName) {
        case 'plate-lookup':
            appWindow = 'plate-lookup-app';
            initialTab = 'search'; // Default to search tab
            // ### Ensure Nearby tab/pane are hidden when app opens ###
            $('#plate-lookup-app .tab[data-tab="nearby"]').hide();
            $('#nearby-tab').hide();
            // ######################################################
            break;
        case 'phone-tracker':
            appWindow = 'phone-tracker-app';
            // Check if phone tracker is enabled
            $.post('https://qb-hackerjob/getPhoneTools', JSON.stringify({}), function(response) {
                if (!response.enabled) {
                    // TODO: Show error message that this tool is disabled
                }
            });
            break;
        case 'radio-decrypt':
            appWindow = 'radio-decrypt-app';
            // Check if radio decryption is enabled
            $.post('https://qb-hackerjob/getRadioTools', JSON.stringify({}), function(response) {
                if (!response.enabled) {
                    // TODO: Show error message that this tool is disabled
                }
            });
            break;
        default:
            console.error('Unknown app:', appName);
            return;
    }

    // Open the app window
    activeAppWindow = appWindow;
    $(`#${appWindow}`).removeClass('hidden');

    // Set initial active tab if specified
    if (initialTab) {
        // Deactivate all tabs and panes first
        $(`#${appWindow}`).find('.tab').removeClass('active');
        $(`#${appWindow}`).find('.tab-pane').removeClass('active');

        // Activate the specified initial tab and pane
        $(`#${appWindow}`).find(`.tab[data-tab="${initialTab}"]`).addClass('active');
        $(`#${appWindow}`).find(`#${initialTab}-tab`).addClass('active');
    } else {
        // Default behavior if no initial tab (e.g., for other apps)
        // Ensure the first tab/pane is active if none specified
        if ($(`#${appWindow}`).find('.tab.active').length === 0) {
            $(`#${appWindow}`).find('.tab:first').addClass('active');
            $(`#${appWindow}`).find('.tab-pane:first').addClass('active');
        }
    }

    // Ensure the app window is draggable and resizable if needed
    // Consider making windows draggable:
    // $(`#${appWindow}`).draggable({ handle: ".window-header" });
}

// Close an app window
function closeApp(appWindowId) {
    $(`#${appWindowId}`).addClass('hidden');
    activeAppWindow = null;
}

// Minimize an app window
function minimizeApp(appWindowId) {
    $(`#${appWindowId}`).addClass('hidden');
    activeAppWindow = null;
}

// Update the clock in the taskbar
function updateClock() {
    const now = new Date();
    const hours = now.getHours().toString().padStart(2, '0');
    const minutes = now.getMinutes().toString().padStart(2, '0');
    $('#clock').text(`${hours}:${minutes}`);
}

// Play sound effects - Empty function that does nothing
function playSound(sound) {
    // Function is intentionally empty to disable all sounds
    // Keeping the function to avoid breaking existing code that calls it
    return;
}

// Vehicle Functions

// Search for a plate
function searchPlate(plate) {
    if (!plate) return;

    // Show loading animation
    $('#vehicle-info').html('<div class="loading-text">Searching database for plate ' + plate + '...</div>');

    // Change to results tab
    $('#plate-lookup-app .tab[data-tab="results"]').click();

    // Call the server to search for the plate
    $.post('https://qb-hackerjob/lookupPlate', JSON.stringify({
        plate: plate
    }), function(response) {
        // Handle server response
        if (!response.success) {
            $('#vehicle-info').html('<div class="no-results">Error: Could not retrieve data.</div>');
        }
    });
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
    // Normal action handling
    $.post('https://qb-hackerjob/performVehicleAction', JSON.stringify({
        action: action,
        plate: plate
    }), function(response) {
        if (response.success) {
            showActionSuccess(action, plate);
        } else {
            showActionFailed(action, plate);
        }
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

// NUI Message Handler
window.addEventListener('message', function(event) {
    const data = event.data;

    if (data.action === 'openLaptop' || data.type === 'openLaptop') {
        // Store initial data from Lua
        currentLevel = data.level || 1;
        currentXP = data.xp || 0;
        nextLevelXP = data.nextLevelXP || 100;
        currentLevelName = data.levelName || "Script Kiddie";
        // Call openLaptop function which uses these global vars
        openLaptop(data);
    } else if (data.action === 'closeLaptop') {
        closeLaptop();
    } else if (data.action === 'updateVehicleData') {
        displayVehicleData(data.data);
    } else if (data.action === 'updateNearbyVehicles') {
        // ### DISABLED NEARBY VEHICLES ###
        console.log('Received updateNearbyVehicles event - DISABLED');
        // Reset the nearby vehicles list in the UI
        $('#nearby-vehicles').html('<div class="info-note">Nearby vehicle scanning is disabled. Use the Search tab.</div>');
        nearbyVehicles = []; // Clear local cache too
        // displayNearbyVehicles(data.vehicles); // Don't call this
        // #############################
    } else if (data.action === 'updateBattery') {
        console.log('Received battery update from server:', data);
        // Force create battery indicator if it doesn't exist
        if ($('#battery-indicator').length === 0 || $('#battery-menu').length === 0) {
            console.log('Creating missing battery elements from message handler');
            createBatteryIndicator();
        }
        updateBatteryDisplay(data.level, data.charging);
    } else if (data.action === 'updateHackerStats' || data.type === 'updateHackerStats') {
        console.log('Received hacker stats update:', data);

        // Update global vars (might still be useful elsewhere, e.g., initial load)
        currentLevel = data.level;
        currentXP = data.xp;
        nextLevelXP = data.nextLevelXP;
        currentLevelName = data.levelName;
        
        // Pass the NEW data directly into the display function
        updateHackerStatsDisplay(data.level, data.xp, data.nextLevelXP, data.levelName);
    } else if (data.action === 'phoneTrackResult') {
        // Handle phone track result
    } else if (data.action === 'radioDecryptResult') {
        // Handle radio decrypt result
    }
});

// Function to update the hacker stats display in the taskbar
function updateHackerStatsDisplay(level, xp, nextXP, levelName) {
    const levelElement = $('#hacker-level-name');
    const xpElement = $('#hacker-xp-progress');

    // Update global variables as well, as they might be used elsewhere
    currentLevel = level;
    currentXP = xp;
    nextLevelXP = nextXP;
    currentLevelName = levelName;

    // Ensure elements exist before trying to update
    if (levelElement.length > 0) {
        levelElement.text(levelName || `Level ${level}`); // Use .text() for simplicity
    } else {
        console.warn("Could not find #hacker-level-name element to update.");
    }

    // Ensure nextLevelXP is a number and greater than 0 to avoid division by zero or NaN
    const displayNextXP = (typeof nextXP === 'number' && nextXP > 0) ? nextXP : '?';

    if (xpElement.length > 0) {
        xpElement.text(`XP: ${xp} / ${displayNextXP}`); // Use .text() for simplicity
    } else {
         console.warn("Could not find #hacker-xp-progress element to update.");
    }

    // Optional: Keep the repaint trick if needed, but often .text() is enough
    // $('.taskbar').css('opacity', '0.99');
    // setTimeout(() => $('.taskbar').css('opacity', '1'), 50);
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

// Drag functionality for laptop window
function setupDragFunctionality() {
    const laptopContainer = document.getElementById('laptop-container');
    let isDragging = false;
    let currentX = 0;
    let currentY = 0;
    let initialX = 0;
    let initialY = 0;
    let xOffset = 0;
    let yOffset = 0;

    // Mouse events
    laptopContainer.addEventListener('mousedown', dragStart);
    document.addEventListener('mousemove', dragMove);
    document.addEventListener('mouseup', dragEnd);

    // Touch events for mobile support
    laptopContainer.addEventListener('touchstart', dragStart);
    document.addEventListener('touchmove', dragMove);
    document.addEventListener('touchend', dragEnd);

    function dragStart(e) {
        // Allow dragging from taskbar area only (avoid interfering with app content)
        const target = e.target;
        const isTaskbarArea = target.closest('.taskbar') || target.classList.contains('taskbar');
        
        if (!isTaskbarArea) return; // Only drag from taskbar area
        
        if (e.type === 'touchstart') {
            initialX = e.touches[0].clientX - xOffset;
            initialY = e.touches[0].clientY - yOffset;
        } else {
            initialX = e.clientX - xOffset;
            initialY = e.clientY - yOffset;
        }

        isDragging = true;
        laptopContainer.style.transition = 'none';
    }

    function dragMove(e) {
        if (isDragging) {
            e.preventDefault();
            
            if (e.type === 'touchmove') {
                currentX = e.touches[0].clientX - initialX;
                currentY = e.touches[0].clientY - initialY;
            } else {
                currentX = e.clientX - initialX;
                currentY = e.clientY - initialY;
            }

            xOffset = currentX;
            yOffset = currentY;

            // Keep window within viewport bounds
            const rect = laptopContainer.getBoundingClientRect();
            const maxX = window.innerWidth - rect.width;
            const maxY = window.innerHeight - rect.height;
            
            xOffset = Math.max(-rect.width / 2, Math.min(xOffset, maxX - rect.width / 2));
            yOffset = Math.max(-rect.height / 2, Math.min(yOffset, maxY - rect.height / 2));

            laptopContainer.style.transform = `translate(calc(-50% + ${xOffset}px), calc(-50% + ${yOffset}px))`;
        }
    }

    function dragEnd() {
        if (isDragging) {
            isDragging = false;
            laptopContainer.style.transition = 'opacity 0.3s ease';
        }
    }
}
