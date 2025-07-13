local Translations = {
    error = {
        not_hacker = 'You are not a hacker',
        no_laptop = 'You need a hacking laptop',
        cooldown = 'You need to wait %{time} seconds',
        no_vehicle = 'No vehicle found',
        query_timeout = 'Database query timed out',
        db_error = 'Database error occurred',
        vehicle_not_found = 'Vehicle not found in database',
        invalid_input = 'Invalid input',
        no_player = 'Player not found',
        no_permission = 'You do not have permission to do this',
        police_alert = 'Police have been alerted',
        system_overload = 'System overloaded. Try again later',
        invalid_plate = 'Invalid plate number',
        radio_signal_not_found = 'No radio signal found',
        operation_failed = 'Operation failed',
        target_offline = 'Target is offline',
        no_access = 'Access denied',
    },
    success = {
        laptop_opened = 'Hacking laptop opened',
        vehicle_found = 'Vehicle information retrieved',
        phone_tracked = 'Phone tracked successfully',
        radio_decrypted = 'Radio frequency decrypted',
        access_granted = 'Access granted',
        vehicle_marked = 'Vehicle marked in system',
    },
    info = {
        using_laptop = 'Using hacking laptop...',
        searching_db = 'Searching database...',
        accessing_database = 'Accessing vehicle database...',
        processing_data = 'Processing data...',
        loading_vehicle_data = 'Loading vehicle data...',
        establishing_connection = 'Establishing secure connection...',
        decrypting_signal = 'Decrypting radio signal...',
        triangulating_position = 'Triangulating phone position...',
        locating_target = 'Locating target...',
        analyzing_data = 'Analyzing data...',
        verifying_credentials = 'Verifying credentials...',
    },
    laptop = {
        main_title = 'Hacker Terminal v1.0',
        welcome_message = 'Welcome to the Hacker Terminal. Choose a tool:',
        plate_lookup = 'Vehicle Plate Lookup',
        phone_tracker = 'Phone Tracker',
        radio_decrypt = 'Radio Decryption',
        phone_hacking = 'Phone Hacking',
        vehicle_control = 'Vehicle Control',
        close_laptop = 'Close Laptop',
        enter_plate = 'Enter plate number:',
        enter_phone = 'Enter phone number:',
        enter_frequency = 'Enter radio frequency:',
        search_button = 'Search',
        track_button = 'Track',
        decrypt_button = 'Decrypt',
        hack_button = 'Hack',
        control_button = 'Control',
        back_button = 'Back',
        exit_button = 'Exit',
        boot_message = 'Booting secure system...',
        shutdown_message = 'Shutting down...',
        plate_result_title = 'Vehicle Information',
        phone_result_title = 'Phone Location',
        radio_result_title = 'Decrypted Transmission',
        security_level = 'Security Level',
        battery_level = 'Battery: %{level}%',
        level_display = 'Hacker Level: %{level} (%{name})',
        xp_display = 'XP: %{current}/{next}',
    },
    vehicle_info = {
        plate = 'Plate: %{plate}',
        owner = 'Owner: %{owner}',
        make_model = 'Make/Model: %{make} %{model}',
        class = 'Class: %{class}',
        vin = 'VIN: %{vin}',
        status = 'Status: %{status}',
        not_registered = 'Not Registered',
        stolen_flag = 'STOLEN',
        police_flag = 'LAW ENFORCEMENT',
        emergency_flag = 'EMERGENCY SERVICES',
        flagged = 'FLAGGED',
        rental = 'RENTAL',
        npc_owned = 'NPC Owned',
        civilian_owned = 'Civilian Owned',
    },
    phone_tracker = {
        target_name = 'Target: %{name}',
        location = 'Location: %{location}',
        distance = 'Distance: ~%{distance}m',
        signal_strength = 'Signal Strength: %{strength}%',
        last_known = 'Last Known Activity: %{time}',
        unknown_location = 'Location Unknown',
        no_signal = 'No Signal',
        tracking_progress = 'Tracking Progress: %{progress}%',
    },
    radio_decryption = {
        frequency = 'Frequency: %{freq} MHz',
        channel = 'Channel: %{channel}',
        message = 'Message: %{message}',
        decryption_progress = 'Decryption Progress: %{progress}%',
        signal_quality = 'Signal Quality: %{quality}%',
        cannot_decrypt = 'Cannot decrypt transmission',
        no_transmission = 'No transmission found',
        partial_decrypt = 'Partial decryption: %{text}',
    },
    commands = {
        open_laptop = 'Open hacking laptop',
        check_xp = 'Check your hacker XP and level',
    },
    phone_hacking = {
        title = 'Phone Hacking',
        enter_number = 'Enter phone number to hack:',
        hack_button = 'Hack',
        cracking_password = 'Cracking password...',
        captcha_challenge = 'CAPTCHA Challenge',
        password_challenge = 'Password Challenge',
        success_message = 'Access granted! Retrieving data...',
        calls_tab = 'Calls',
        messages_tab = 'Messages',
        call_date = 'Date',
        call_number = 'Number',
        call_duration = 'Duration',
        message_date = 'Date',
        message_from = 'From',
        message_to = 'To',
        message_content = 'Message',
        intrusion_detected = 'Intrusion attempt detected!',
        password_failed = 'Password cracking failed!'
    },
    skill_system = {
        xp_gained = 'Hacking XP: +%{amount}',
        level_up = 'Level Up! You are now a %{level_name}',
        level_info = 'Hacker Level: %{level} (%{name})',
        xp_progress = 'XP: %{xp} | Progress to next level: %{progress}%',
        feature_locked = 'You need a higher hacker level to use %{feature}',
        max_level = 'You have reached the maximum hacker level'
    },
    trace_system = {
        high_warning = 'Warning: Your trace level is getting high!',
        critical_warning = 'Warning: Your trace level is critically high!',
        reduced_message = 'Your trace level has decreased to a safer level.',
        police_alert = 'Suspicious network activity detected'
    },
    vehicle_control = {
        select_vehicle = 'Select a tracked vehicle:',
        unlock_vehicle = 'Unlock Vehicle',
        lock_vehicle = 'Lock Vehicle',
        engine_on = 'Start Engine',
        engine_off = 'Stop Engine',
        disable_vehicle = 'Disable Vehicle',
        no_vehicles = 'No tracked vehicles available',
        control_success = 'Vehicle control successful',
        control_failed = 'Vehicle control failed',
        connecting = 'Connecting to vehicle systems...',
        security_bypass = 'Bypassing security...',
        access_granted = 'Remote access granted',
        access_denied = 'Remote access denied',
        vehicle_unavailable = 'Vehicle is no longer available',
        distance_warning = 'Vehicle is too far away for reliable connection'
    }
}

Lang = {}

Lang.t = function(key)
    local keys = {}
    for k in string.gmatch(key, "([^.]+)") do
        table.insert(keys, k)
    end

    local namespace = Translations
    for i=1, #keys do
        namespace = namespace[keys[i]]
        if namespace == nil then
            return key
        end
    end

    return namespace
end

if GetConvar('qb_locale', 'en') == 'en' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang,
    })
end 