const checkbox = document.querySelector("input[type='checkbox']");
const mode_switch_icon = document.querySelector(".mode-switch-icon");

// configure and set correct state of theme checkbox
checkbox.checked = siteVars['theme_active'] == 'dark'
checkbox.addEventListener("click", () => {
    theme_switch();
    set_theme_checkbox();
});

set_theme_checkbox();

// set correct state of dark/light theme mode
function set_theme_checkbox() {
    if (checkbox.checked) {
        mode_switch_icon.classList.add("mode-switch-dark");
        mode_switch_icon.classList.remove("mode-switch-light");
    } else {
        mode_switch_icon.classList.add("mode-switch-light");
        mode_switch_icon.classList.remove("mode-switch-dark");
    }
}

// switch dark/light mode and store the state to local storage
function theme_switch() {
    if (siteVars['theme_active'] == 'light') {
        siteVars['theme_active'] = siteVars['theme_forced'] = 'dark';

        document.getElementById('css-darkmode').setAttribute('media', 'all');
        document.getElementById('css-darkmode').disabled = false;

        document.getElementById('css-lightmode').setAttribute('media', 'not all');
        document.getElementById('css-lightmode').disabled = true;
    } else {
        siteVars['theme_active'] = siteVars['theme_forced'] = 'light';

        document.getElementById('css-darkmode').setAttribute('media', 'not all');
        document.getElementById('css-darkmode').disabled = true;

        document.getElementById('css-lightmode').setAttribute('media', 'all');
        document.getElementById('css-lightmode').disabled = false;
    }
    localStorage.setItem('theme_forced', siteVars['theme_active']);

    document.body.classList.add('expand');
    document.body.offsetHeight;
    document.body.classList.remove('expand');
}
