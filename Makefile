push: output ldoc changelogs manpages
	rsync -PaOvz --chmod=u=rwX,g=rwX,o=rX,Dg+s --exclude src html/ awesome.naquadah.org:/var/www/awesome.naquadah.org/
	rsync -PaOvz --chmod=u=rwX,g=rwX,o=rX,Dg+s --delete src/build/doc/ awesome.naquadah.org:/var/www/awesome.naquadah.org/doc/api
	rsync -PaOvz --chmod=u=rwX,g=rwX,o=rX,Dg+s /usr/share/asciidoc/icons awesome.naquadah.org:/var/www/awesome.naquadah.org/doc/manpages/icons

output: authors.mdwn
	ikiwiki $(CURDIR) html -v --wikiname about --plugin=goodstuff --templatedir=templates \
	  --exclude=html --exclude=Makefile --rss --url https://awesomewm.org/

authors.mdwn:
	echo '## Primary' > authors.mdwn
	echo '<pre>' >> authors.mdwn
	git --git-dir=src/.git shortlog -n -s | head -n 10 | column -x -c 80 >> authors.mdwn
	echo '</pre>' >> authors.mdwn
	echo '## Contributors' >> authors.mdwn
	echo '<pre>' >> authors.mdwn
	git --git-dir=src/.git shortlog -n -s | tail -n +11 | column -x -c 80 >> authors.mdwn
	echo '</pre>' >> authors.mdwn
ldoc:
	rm -f src/build
	make -C src build cmake ldoc

clean:
	rm -rf .ikiwiki html

changelogs:
	test -d html/changelogs/short || mkdir -p html/changelogs/short
	git --git-dir=src/.git tag | grep -v rc | sort -n | \
	    (while read v; do \
	    test -z "$$pv" && pv="`git --git-dir=src/.git rev-list HEAD | tail -n1`" ; \
	    git --git-dir=src/.git shortlog $$pv..$$v > html/changelogs/short/$$v ; \
	    git --git-dir=src/.git log $$pv..$$v > html/changelogs/$$v ; \
	    pv=$$v; done)

manpages:
	mkdir -p html/doc/manpages
	cd src/manpages; for manpage in *.?.txt; \
	    do asciidoc -a icons -b xhtml11 -o ../../html/doc/manpages/`basename $${manpage} .txt`.html $$manpage || exit 1; \
	    done

.PHONY: authors.mdwn changelogs manpages
