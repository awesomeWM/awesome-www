ifeq ($(shell which ikiwiki),)
IKIWIKI=echo "** ikiwiki not found" >&2 ; echo ikiwiki
else
IKIWIKI=ikiwiki
endif

push: output
	rsync -Pavz html/ delmak.naquadah.org:/var/www/awesome.naquadah.org/

output:
	$(IKIWIKI) `pwd` html -v --wikiname about --plugin=goodstuff --templatedir=templates \
	    --exclude=html --exclude=Makefile --rss --url http://awesome.naquadah.org

clean:
	rm -rf .ikiwiki html
