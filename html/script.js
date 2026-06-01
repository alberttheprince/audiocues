(function() {
    const container = document.getElementById('container');
    const notificationsEl = document.getElementById('notifications');
    const indicator = document.getElementById('indicator');
    const MAX_NOTIFICATIONS = 6;
    let notifications = [];
    let isProcessing = false;
    let notificationQueue = [];
    let showTimestamp = true; // Default to true, updated by config
    let isEnabled = false; // Track if system is enabled
    let currentPosition = 'top'; // Current position

    // Arc sizes based on distance (narrower = more precise, wider = less precise)
    const ARC_SIZES = {
        close: 40,    // Narrow arc - close sounds are easy to pinpoint
        medium: 70,   // Medium arc
        far: 120      // Wide arc - distant sounds harder to locate precisely
    };

    function formatTime() {
        const now = new Date();
        return now.toLocaleTimeString('en-US', { 
            hour: '2-digit', 
            minute: '2-digit',
            second: '2-digit',
            hour12: false 
        });
    }

    function updateIndicatorVisibility() {
        const hasNotifications = notifications.filter(n => !n.removing).length > 0;
        indicator.style.opacity = hasNotifications ? '0' : '1';
    }

    function applyPosition(position) {
        // Remove all position classes
        container.classList.remove('position-top', 'position-left', 'position-right', 'position-bottom');
        
        // Add the appropriate position class
        currentPosition = position || 'top';
        container.classList.add('position-' + currentPosition);
    }

    // Create SVG arc for direction indicator
    function createDirectionIndicator(angle, distanceCategory) {
        if (angle === null || angle === undefined) {
            return '<div class="direction-indicator empty"></div>';
        }

        const size = 24;
        const center = size / 2;
        const radius = 9;
        const arcAngle = ARC_SIZES[distanceCategory] || ARC_SIZES.medium;
        const halfArc = arcAngle / 2;
        
        // Convert angle: 0 = top (ahead), 90 = right, 180 = bottom (behind), 270 = left
        // SVG: 0 = right, so we need to adjust
        const startAngle = angle - halfArc - 90;
        const endAngle = angle + halfArc - 90;
        
        const startRad = (startAngle * Math.PI) / 180;
        const endRad = (endAngle * Math.PI) / 180;
        
        const x1 = center + radius * Math.cos(startRad);
        const y1 = center + radius * Math.sin(startRad);
        const x2 = center + radius * Math.cos(endRad);
        const y2 = center + radius * Math.sin(endRad);
        
        const largeArc = arcAngle > 180 ? 1 : 0;
        
        // Create pie slice path (from center to arc and back)
        const pathData = `M ${center} ${center} L ${x1} ${y1} A ${radius} ${radius} 0 ${largeArc} 1 ${x2} ${y2} Z`;
        
        return `
            <div class="direction-indicator">
                <svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
                    <circle cx="${center}" cy="${center}" r="${radius}" class="direction-ring"/>
                    <path d="${pathData}" class="direction-arc"/>
                    <circle cx="${center}" cy="${center}" r="2" class="direction-center"/>
                </svg>
            </div>
        `;
    }

    function createNotificationElement(data) {
        const el = document.createElement('div');
        el.className = `notification ${data.severity || 'neutral'}`;
        el.dataset.icon = data.icon;
        el.dataset.priority = data.priority || 2;
        
        const directionIndicator = createDirectionIndicator(data.directionAngle, data.distanceCategory);
        const timeElement = showTimestamp ? `<div class="notification-time">${formatTime()}</div>` : '';
        
        el.innerHTML = `
            <div class="notification-icon">${data.icon}</div>
            <div class="notification-message">${data.message}</div>
            ${directionIndicator}
            ${timeElement}
            <div class="notification-progress" style="animation-duration: ${data.duration}ms;"></div>
        `;
        return el;
    }

    function removeNotificationImmediate(notification) {
        clearTimeout(notification.timeout);
        if (notification.element.parentNode) {
            notification.element.parentNode.removeChild(notification.element);
        }
        notifications = notifications.filter(n => n !== notification);
        updateIndicatorVisibility();
    }

    function removeNotification(notification) {
        clearTimeout(notification.timeout);
        if (notification.removing) return;
        notification.removing = true;
        
        notification.element.classList.add('removing');
        
        setTimeout(() => {
            if (notification.element.parentNode) {
                notification.element.parentNode.removeChild(notification.element);
            }
            notifications = notifications.filter(n => n !== notification);
            updateIndicatorVisibility();
        }, 200);
    }

    function findExistingNotification(icon) {
        return notifications.find(n => n.element.dataset.icon === icon && !n.removing);
    }

    function findLowestPriorityNotification(belowPriority) {
        let lowest = null;
        for (const n of notifications) {
            if (n.removing) continue;
            const priority = parseInt(n.element.dataset.priority) || 2;
            if (priority < belowPriority) {
                if (!lowest || priority < parseInt(lowest.element.dataset.priority)) {
                    lowest = n;
                }
            }
        }
        return lowest;
    }

    function clearAllNotifications() {
        notificationQueue = [];
        notifications.forEach(n => {
            clearTimeout(n.timeout);
            if (n.element.parentNode) {
                n.element.parentNode.removeChild(n.element);
            }
        });
        notifications = [];
        isProcessing = false;
        updateIndicatorVisibility();
    }

    function processQueue() {
        if (!isEnabled || isProcessing || notificationQueue.length === 0) return;
        
        isProcessing = true;
        const data = notificationQueue.shift();
        const newPriority = data.priority || 2;
        
        if (data.override) {
            clearAllNotifications();
        }
        
        const existing = findExistingNotification(data.icon);
        if (existing) {
            clearTimeout(existing.timeout);
            existing.element.querySelector('.notification-message').textContent = data.message;
            const timeEl = existing.element.querySelector('.notification-time');
            if (timeEl) timeEl.textContent = formatTime();
            existing.element.className = `notification ${data.severity || 'neutral'}`;
            existing.element.dataset.priority = newPriority;
            
            // Update direction indicator
            const oldIndicator = existing.element.querySelector('.direction-indicator');
            if (oldIndicator) {
                oldIndicator.outerHTML = createDirectionIndicator(data.directionAngle, data.distanceCategory);
            }
            
            const progress = existing.element.querySelector('.notification-progress');
            progress.style.animation = 'none';
            progress.offsetHeight;
            progress.style.animation = `progress ${data.duration}ms linear forwards`;
            
            existing.timeout = setTimeout(() => {
                removeNotification(existing);
            }, data.duration);
            
            isProcessing = false;
            processQueue();
            return;
        }
        
        const activeCount = notifications.filter(n => !n.removing).length;
        if (activeCount >= MAX_NOTIFICATIONS) {
            const toRemove = findLowestPriorityNotification(newPriority);
            if (toRemove) {
                removeNotificationImmediate(toRemove);
            } else {
                const sameOrLower = notifications.find(n => 
                    !n.removing && parseInt(n.element.dataset.priority) <= newPriority
                );
                if (sameOrLower) {
                    removeNotificationImmediate(sameOrLower);
                } else {
                    isProcessing = false;
                    processQueue();
                    return;
                }
            }
        }

        const element = createNotificationElement(data);
        notificationsEl.appendChild(element);

        const notification = {
            element: element,
            removing: false,
            timeout: setTimeout(() => {
                removeNotification(notification);
            }, data.duration)
        };

        notifications.push(notification);
        updateIndicatorVisibility();
        
        isProcessing = false;
        
        if (notificationQueue.length > 0) {
            setTimeout(processQueue, 30);
        }
    }

    function addNotification(data) {
        notificationQueue.push(data);
        processQueue();
    }

    window.addEventListener('message', function(event) {
        const data = event.data;

        switch (data.type) {
            case 'toggle':
                if (data.enabled) {
                    isEnabled = true;
                    container.classList.remove('hidden');
                    
                    // Update settings from config
                    if (data.showTimestamp !== undefined) {
                        showTimestamp = data.showTimestamp;
                    }
                    
                    // Apply dynamic width if provided
                    if (data.notificationWidth) {
                        container.style.setProperty('--notification-width', data.notificationWidth + 'px');
                    }
                    
                    // Apply position
                    applyPosition(data.position);
                    
                    // Clear any existing notifications so indicator is visible
                    clearAllNotifications();
                    
                    indicator.textContent = 'Audio Cue Mode Active';
                    indicator.style.opacity = '1';
                    
                    // Flash green when enabled
                    indicator.classList.remove('flash-off');
                    indicator.classList.remove('flash-on');
                    void indicator.offsetWidth; // Trigger reflow
                    indicator.classList.add('flash-on');
                } else {
                    isEnabled = false;
                    
                    // Clear any existing notifications so indicator is visible
                    clearAllNotifications();
                    
                    // Clear the queue too
                    notificationQueue = [];
                    
                    // Show indicator for the flash
                    indicator.textContent = 'Audio Cue Mode Disabled';
                    indicator.style.opacity = '1';
                    
                    // Flash red when disabled
                    indicator.classList.remove('flash-on');
                    indicator.classList.remove('flash-off');
                    void indicator.offsetWidth; // Trigger reflow
                    indicator.classList.add('flash-off');
                    
                    // Hide container after flash animation
                    setTimeout(() => {
                        container.classList.add('hidden');
                    }, 1000);
                }
                break;

            case 'notification':
                // Ignore notifications if disabled
                if (!isEnabled) break;
                addNotification(data);
                break;

            case 'updatePosition':
                applyPosition(data.position);
                break;

            case 'clear':
                clearAllNotifications();
                break;
        }
    });
})();
