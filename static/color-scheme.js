function getTheme() {
    return localStorage.getItem("theme") || "system";
}

function setTheme(themeName) {
    localStorage.setItem('theme', themeName);
    const isDark = themeName === "dark" || (themeName === "system" && window.matchMedia("(prefers-color-scheme: dark)").matches);
    document.documentElement.setAttribute('data-theme', isDark ? "dark" : "light");
    
    // Update toggle icons if they exist
    const darkIcon = document.getElementById('theme-toggle-dark-icon');
    const lightIcon = document.getElementById('theme-toggle-light-icon');
    
    if (darkIcon && lightIcon) {
        if (isDark) {
            darkIcon.classList.remove('hidden');
            lightIcon.classList.add('hidden');
        } else {
            lightIcon.classList.remove('hidden');
            darkIcon.classList.add('hidden');
        }
    }
}

// Initial setup
setTheme(getTheme());

document.addEventListener("DOMContentLoaded", function() {
    const themeToggleBtn = document.getElementById('theme-toggle');
    
    function toggleTheme() {
        const currentTheme = getTheme();
        const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
        
        // Toggle logic: If currently system, explicitize it. Then flip.
        let isCurrentlyDark = currentTheme === "dark" || (currentTheme === "system" && prefersDark);
        
        setTheme(isCurrentlyDark ? "light" : "dark");
    }

    if (themeToggleBtn) {
        themeToggleBtn.addEventListener('click', toggleTheme);
    }

    // Global shortcut to toggle theme (Cmd+T or Ctrl+T)
    document.addEventListener("keydown", (ev) => {
        if ((ev.metaKey || ev.ctrlKey) && ev.key.toLowerCase() === 't') {
            ev.preventDefault();
            toggleTheme();
        }
    });

    // also check to see if the user changes their system theme settings while the page is loaded.
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', event => {
        if (getTheme() === "system") {
            setTheme("system");
        }
    });
});
