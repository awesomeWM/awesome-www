ifeq ($(shell which ikiwiki),)
IKIWIKI=echo "** ikiwiki not found" >&2 ; echo ikiwiki
else
IKIWIKI=ikiwiki
endif

push: output luadoc
	rsync -Pavz --exclude src html/ awesome.naquadah.org:/var/www/awesome.naquadah.org/
	rsync -Pavz src/build/luadoc/ awesome.naquadah.org:/var/www/awesome.naquadah.org/apidoc

output:
	$(IKIWIKI) $(CURDIR) html -v --wikiname about --plugin=goodstuff --templatedir=templates \
	    --exclude=html --exclude=Makefile --rss --url http://awesome.naquadah.org/newsite
luadoc:
	 make -C src build cmake luadoc

clean:
	rm -rf .ikiwiki html

