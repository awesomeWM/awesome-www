# Make git not use user's config.
OLD_HOME:=$(HOME)
HOME:=/dev/null

all: output ldoc changelogs manpages

output:
	ikiwiki $(CURDIR) html -v --wikiname about --plugin=goodstuff \
	  --templatedir=templates \
	  --exclude=html --exclude=Makefile --exclude=README.md \
	  --exclude=README.for_webpage.md
	echo awesomewm.org > html/CNAME
	cp README.for_webpage.md html/README.md

ldoc:
	rm -f src/build
	HOME=$(OLD_HOME) make -C src cmake-build ldoc

clean:
	rm -rf .ikiwiki html

changelogs:
	test -d html/changelogs/short || mkdir -p html/changelogs/short
	git --git-dir=src/.git tag | grep -v rc | sort -n | \
	    (while read v; do \
	    test -z "$$pv" && pv="`git --git-dir=src/.git rev-list HEAD | tail -n1`" ; \
	    git --git-dir=src/.git shortlog --no-merges $$pv..$$v > html/changelogs/short/$$v.txt ; \
	    git --git-dir=src/.git log --no-merges $$pv..$$v > html/changelogs/$$v.txt ; \
	    pv=$$v; done)

manpages:
	mkdir -p html/doc/manpages
	cd src/manpages; for manpage in *.?.txt; \
	    do asciidoc -a icons -b xhtml11 -o ../../html/doc/manpages/`basename $${manpage} .txt`.html $$manpage || exit 1; \
	    done

build_for_travis: all
	rsync -PaOvz --delete --exclude=.git --chmod=u=rwX,g=rwX,o=rX,Dg+s --exclude src html/ \
	  $${BUILD_WEB}
	rsync -PaOvz --delete --chmod=u=rwX,g=rwX,o=rX,Dg+s src/build/doc/ \
	  $${BUILD_WEB}/doc/api
	rsync -PaOvz --delete --chmod=u=rwX,g=rwX,o=rX,Dg+s /usr/share/asciidoc/icons \
	  $${BUILD_WEB}/doc/manpages/icons

.PHONY: changelogs manpages
