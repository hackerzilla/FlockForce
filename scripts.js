// theme-switcher.js (or scripts.js)

document.addEventListener('DOMContentLoaded', () => {
    const themeToggleButton = document.getElementById('theme-toggle-button');
    const body = document.body;

    // Function to apply theme based on preference
    const applyTheme = (theme) => {
        // ... (keep the rest of the applyTheme function as it was) ...
        if (theme === 'dark') {
            body.classList.add('dark-theme');
            body.classList.remove('light-theme'); // Ensure light is removed
            themeToggleButton.textContent = 'Switch to Light Mode';
        } else {
            body.classList.add('light-theme'); // Add light class
            body.classList.remove('dark-theme');
            themeToggleButton.textContent = 'Switch to Dark Mode';
        }
    };

    // Check localStorage for saved theme preference
    const savedTheme = localStorage.getItem('theme') || 'light';
    applyTheme(savedTheme);

    // Add event listener to the button
    themeToggleButton.addEventListener('click', () => {
        // === ADD THIS LINE FOR TESTING ===
        console.log("Button clicked!");
        // ===================================

        let newTheme;
        if (body.classList.contains('dark-theme')) {
            newTheme = 'light';
        } else {
            newTheme = 'dark';
        }
        applyTheme(newTheme);
        localStorage.setItem('theme', newTheme);
    });

    // Add a check to make sure the button was found
    if (!themeToggleButton) {
        console.error("Error: Could not find button with ID 'theme-toggle-button'");
    }

}); // End of DOMContentLoaded listener