# Website for awesome WM

[![Build Status](https://travis-ci.org/awesomeWM/awesome-www.svg?branch=master)](https://travis-ci.org/awesomeWM/awesome-www)

This is the main source of the
[website for the awesome window manager](https://awesomewm.org/).

The website is based on [ikiwiki](https://ikiwiki.info/). You can build the web
page locally by running `make`. The result will be in `html/`. Besides ikiwiki,
you will also need [PerlMagick](https://www.imagemagick.org/script/perl-magick.php).

## Contribution Guide

### Screenshots

To contribute with Screenshots:
* Add your image to the folder images/screenshots with an appropiated name.
* Add a new <figure> tag in the bottom of *screenshots.mdwn*,
* Inside the new tag, add the screenshots with a <img> tag and use the <figcaption> to add caption to the image, explaining what is being used on the screenshot.

## Publishing

The master branch gets built by
[Travis CI](https://travis-ci.org/awesomeWM/awesome-www/), and is then published
through [Github's Organization Pages](https://github.com/awesomeWM/awesomeWM.github.io).

## Other resources

The API documentation for the master branch at
[/apidoc](https://awesomewm.org/apidoc/) is served through [Github's Project
Pages for the apidoc repo](https://github.com/awesomeWM/apidoc), where it gets
pushed to from successful builds in [the awesome main
repo](https://github.com/awesomeWM/awesome/).
