const checkbox = document.querySelector("input[type='checkbox']");
const slider = document.querySelector('.slider');

// configure and set correct state of theme checkbox
checkbox.checked = siteVars['theme_active'] == 'dark'
checkbox.addEventListener("click", () => {
    theme_switch();
    set_theme_checkbox();
    scrollFunction();
});

set_theme_checkbox();

// set correct state of dark/light theme mode
function set_theme_checkbox() {
    if (checkbox.checked) {
        slider.classList.add("slider-dark");
        slider.classList.remove("slider-light");
    } else {
        slider.classList.remove("slider-dark");
        slider.classList.add("slider-light");
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
