let siteVars = new Array();
siteVars['theme_active'] = 'light';
siteVars['theme_forced'] = '';

// combine prefers color theme or custom selected user dark/light theme
let themeForcedStored = localStorage.getItem('theme_forced');
if (themeForcedStored == 'light' || themeForcedStored == 'dark') {
    siteVars['theme_forced'] = themeForcedStored;
}

siteVars['theme_active'] = 'light';
if ((window.matchMedia &&
  window.matchMedia('(prefers-color-scheme: dark)').matches) ||
  siteVars['theme_forced'] == 'dark') {
    siteVars['theme_active'] = 'dark';
}

if (siteVars['theme_forced'] != '') {
    siteVars['theme_active'] = siteVars['theme_forced'];
}

if (siteVars['theme_forced'] != '') {
    if (siteVars['theme_forced'] == 'dark') {
        document.getElementById('css-darkmode').setAttribute('media', 'all');
        document.getElementById('css-darkmode').disabled = false;

        document.getElementById('css-lightmode').setAttribute('media', 'not all');
        document.getElementById('css-lightmode').disabled = true;

    } else {
        document.getElementById('css-darkmode').setAttribute('media', 'not all');
        document.getElementById('css-darkmode').disabled = true;

        document.getElementById('css-lightmode').setAttribute('media', 'all');
        document.getElementById('css-lightmode').disabled = false;
    }
}
