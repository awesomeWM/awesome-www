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

## Contributing to the Screenshots Section

To contribute with Screenshots:

1. Add your image to the folder images/screenshots with an appropriate name.

2. Add a new `<figure>` tag in the bottom of *screenshots.mdwn*,

3. Inside the new tag, add the screenshots with a <img> tag and use the `<figcaption>` to add caption to the image, explaining what is being used on the screenshot.

## Contributing to Recipes Section

1. Fork this repository and create a new branch with a name relevant to the information you will be adding to the site.
If you have doubts in how to Fork and Branch, take a look in this cheat-sheet [here](https://www.git-tower.com/blog/git-cheat-sheet/)

The process of editing files can be done inside GitHub's interface, more information [here](https://help.github.com/articles/github-flow/)

#### With external Link

1. Create a new link in markdown format `[Link Name](Real Link)` in the appropriate section in `recipes.mdwn` file.

#### With internal Link (host in awesome site)

1. Create a new page with your tutorial/setup/widget/snippet in Markdown, with a relevant name, under the `recipes` folder.

   - Example `recipes/xrandr-tutorial.mdmw`

2. Link your page to the right section in the `recipes.mdwn` page with Markdown syntax.

   - Example `[XrandR Tutorial](../recipes/xrandr-tutorial.html)`

#### Seeing results and pulling your changes

1. Build the site as explained in the Hacking section in this same page to check how your changes will look like.

2. If everything is right and looks good, you're ready do make a Pull Request.

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
