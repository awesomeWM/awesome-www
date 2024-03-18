let navbar = document.getElementById("navbar");
let navLogoDark = document.getElementById("nav-logo-dark");
let navLogoLight = document.getElementById("nav-logo-light");

window.onscroll = function() { scrollFunction() };
scrollFunction();

let mediaQuery = window.matchMedia('(max-width: 500px)');
mediaChanged(mediaQuery);
mediaQuery.addEventListener("change", mediaChanged);

function scrollFunction() {
  if (document.body.scrollTop > 70 || document.documentElement.scrollTop > 70) {
    navbar.style.padding = "10px 10px";
    navbar.style.backgroundColor = "var(--nav-background-color)";
    navbar.style.borderStyle = "solid";
    if (siteVars['theme_forced'] == 'dark') {
      navLogoDark.style.display = "initial";
    } else {
      navLogoLight.style.display = "initial";
    }
  } else {
    navbar.style.padding = "25px 10%";
    navbar.style.backgroundColor = "var(--nav-background-color-transparent)";
    navbar.style.borderStyle = "hidden";
    if (siteVars['theme_forced'] == 'dark') {
      navLogoDark.style.width = "300px";
      navLogoDark.style.display = "none";
    } else {
      navLogoLight.style.width = "300px";
      navLogoLight.style.display = "none";
    }
  }
}

function mediaChanged(mediaQuery) {
  navLogoDark.style.width = mediaQuery.matches ? "250px" : "300px";
  navLogoLight.style.width = mediaQuery.matches ? "250px" : "300px";
}
