window.onscroll = function() { scrollFunction() };

scrollFunction();

function scrollFunction() {
  let navbar = document.getElementById("navbar");
  let navLogoDark = document.getElementById("nav-logo-dark");
  let navLogoLight = document.getElementById("nav-logo-light");

  if (document.body.scrollTop > 70 || document.documentElement.scrollTop > 70) {
    navbar.style.padding = "10px 10px";
    navbar.style.backgroundColor = "var(--nav-background-color)";
    navbar.style.borderStyle = "solid";
    if (siteVars['theme_forced'] == 'dark') {
      navLogoDark.style.width = "300px";
      navLogoDark.style.display = "initial";
    } else {
      navLogoLight.style.width = "300px";
      navLogoLight.style.display = "initial";
    }
  } else {
    navbar.style.padding = "35px 10%";
    navbar.style.backgroundColor = "var(--nav-background-color-transparent)";
    navbar.style.borderStyle = "hidden";
    if (siteVars['theme_forced'] == 'dark') {
      navLogoDark.style.width = "400px";
      navLogoDark.style.display = "none";
    } else {
      navLogoLight.style.width = "400px";
      navLogoLight.style.display = "none";
    }
  }
}
