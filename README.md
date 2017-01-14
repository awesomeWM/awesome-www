# Website for awesome WM

[![Build Status](https://travis-ci.org/awesomeWM/awesome-www.svg?branch=master)](https://travis-ci.org/awesomeWM/awesome-www)

This is the main source of the
[website for the awesome window manager](https://awesomewm.org/).

## Requirements

- [ikiwiki](https://ikiwiki.info/)
- [PerlMagick](https://www.imagemagick.org/script/perl-magick.php) (optional,
  for images)

## Hacking

You can build the web page locally by running `make`, which will generate the
output in `html/`.

To view it, open `html/index.html` in your web browser.

You can simulate running a web server using Python, which will automatically
open `index.html` when following a link to a directory:

    $ cd html
    $ python3 -m http.server -b localhost 8000 &

## Publishing

The master branch gets built by
[Travis CI](https://travis-ci.org/awesomeWM/awesome-www/), and is then published
through [Github's Organization Pages](https://github.com/awesomeWM/awesomeWM.github.io).

## Other resources

The API documentation for the master branch at
[/apidoc](https://awesomewm.org/apidoc/) is viewable at [Github's Project
Pages for the apidoc repo](https://github.com/awesomeWM/apidoc), where it gets
pushed to from successful builds in [the awesome main
repo](https://github.com/awesomeWM/awesome/).
