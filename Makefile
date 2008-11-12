ifeq ($(shell which ikiwiki),)
IKIWIKI=echo "** ikiwiki not found" >&2 ; echo ikiwiki
else
IKIWIKI=ikiwiki
endif

push: output luadoc changelogs
	rsync -Pavz --exclude src html/ awesome.naquadah.org:/var/www/awesome.naquadah.org/
	rsync -Pavz src/build/luadoc/ awesome.naquadah.org:/var/www/awesome.naquadah.org/apidoc

output:
	$(IKIWIKI) $(CURDIR) html -v --wikiname about --plugin=goodstuff --templatedir=templates \
	    --exclude=html --exclude=Makefile --rss --url http://awesome.naquadah.org
luadoc:
	 make -C src build cmake all

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
