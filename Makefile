#
# configuration here:
#

url = http://www.sslug.dk/~chlor/lessig/freeculture.sgml.2004-04-01.gz

# PDF rule
# Valid book options are a4paper, a5paper, b5paper, letterpaper,
# legalpaper, landscape, 11pt, 12pt, oneside, twocolumn, notitlepage,
# titlepage, openany, draft, fleqn, leqno
#  -P latex.class.options=a5paper
DBLATEX = dblatex \
	-T simple \
	--param lingua=nb \
	--xsl-user=data/user_param.xsl \
	--xsl-user=data/xetex_param.xsl \
	-p data/pdf.xsl


DBTOEPUB = dbtoepub

IMAGES = images/cc.png

XSLT = \
  data/user_param.xsl

DB_XSLT = \
  data/xetex_param.xsl

HTML_XSLT = \
  $(XSLT) \
  data/html.xsl \
  data/stylesheet-html.xsl

PDF_XSLT = \
  $(XSLT) \
  data/lulu.xsl \
  data/licentia.xsl \
  data/pdf.xsl \
  data/stylesheet-fo.xsl


all: lint lint.nb html epub pdf

freeculture.nb.po: freeculture.pot
	po4a --no-translations --msgmerge-opt --no-location po4a.cfg

freeculture.nb.xml: freeculture.nb.po freeculture.xml
	po4a --translate-only freeculture.nb.xml po4a.cfg 

pdf: freeculture.nb.pdf freeculture.pdf
epub: freeculture.nb.epub 
html: freeculture.html freeculture.nb.html 

%.pdf: %.xml $(IMAGES) $(PDF_XSLT) Makefile
# Possible pipelines:
#
# dblatex:
#   This converts the docbook content to latex and leave it to latex
#   to format it.
#
# xmlto:
#   Alternative processing path to dblatex is to use xmlto using fop
#   to create PDF like this.  The PDF output (visual design) is
#   better, but the footnote handling is worse and images are missing.
#
# docbook-xsl:
#   Third alternative is to use xsltproc and fop directly, as
#   recommended by <URL: http://www.sagehill.net/docbookxsl/index.html >.
#   This include images, but the index refs and footnote handling
#   is broken.

	pipeline=dblatex; \
	echo "Using $$pipeline pipeline" ; \
	case "$$pipeline" in  \
	dblatex) \
	  $(DBLATEX) $< ; \
	  ;; \
	xmlto) \
	  xmlto --noautosize \
	    -x data/stylesheet-fo.xsl \
	    --with-fop pdf $< ; \
	  ;; \
	docbook-xsl) \
	  xsltproc  \
	    --output $(subst .pdf,.fo,$@) \
	    data/stylesheet-fo.xsl \
	    $< ; \
	  fop -c data/fop-params.xconf -fo $(subst .pdf,.fo,$@) -pdf $@ ; \
	  ;; \
	esac

pdf-compare: freeculture.xml $(IMAGES)
	dblatex -o freeculture-dblatex.pdf freeculture.xml
	dblatex -T db2latex \-o freeculture-dblatex-db2latex.pdf freeculture.xml

	# plain xmlto fail
	#xmlto pdf freeculture.xml && mv freeculture.pdf freeculture-xmlto.pdf
	xmlto --with-fop pdf freeculture.xml && mv freeculture.pdf freeculture-xmlto-fop.pdf

	xsltproc --output freeculture-docbook-xsl.fo \
	  /usr/share/xml/docbook/stylesheet/docbook-xsl/fo/docbook.xsl \
	  freeculture.xml
	fop -fo freeculture-docbook-xsl.fo -pdf freeculture-docbook-xsl.pdf

%.html: %.xml $(IMAGES) $(HTML_XSLT)
	xmlto \
	  -x data/stylesheet-html.xsl \
	  html-nochunks \
	  $<

%.txt: %.xml $(IMAGES)
	xmlto txt $<

%.epub: %.xml $(IMAGES)
	$(DBTOEPUB) $<

freeculture.xml:
	GET $(url) | gunzip > freeculture.xml

# <beginpage> workaround can be removed when BTS #684137 is fixed in
# po4a.
freeculture.pot: freeculture.xml
	po4a-gettextize -o nodefault='<beginpage>' -o inline='<beginpage>' \
	  -f docbook -m $^  > $@.new && mv $@.new $@

stats: update-stats progress.png
update-stats: freeculture.nb.po
	( \
	printf "%s " $$(date +"%Y-%m-%dT%H%M") ; \
	msgfmt -o /dev/null --statistics freeculture.nb.po 2>&1 \
	) | tee -a stats.txt
progress.png: stats.txt progress.gnuplot
	awk '{print $$1, $$2, $$5, $$8}' < stats.txt > stats.csv
	gnuplot progress.gnuplot
	rm stats.csv

# Have to disable --postvalid, when using xref with xrefstyle.
# See <URL: http://bugs.debian.org/682944 > for the bug report.
XMLLINTOPTS = --nonet --noout  --xinclude --postvalid 
lint: freeculture.xml
	xmllint $(XMLLINTOPTS) freeculture.xml

lint.nb: freeculture.nb.xml
	xmllint  $(XMLLINTOPTS) freeculture.nb.xml

images/cc.svg:
	wget -O $@ http://upload.wikimedia.org/wikipedia/commons/9/97/CC_some_rights_reserved_new_2.svg

images/cc.png: images/cc.svg
	inkscape -z -D --export-height=200 -D --export-png=$(shell pwd)/$@ $^
