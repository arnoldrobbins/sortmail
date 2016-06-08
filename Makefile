SOURCE = sortmail.twjr
TEXISOURCE = sortmail.texi

all: sortmail.awk pdf html xml info

$(TEXISOURCE): $(SOURCE)
	jrweave $(SOURCE) > $(TEXISOURCE)

sortmail.awk: $(SOURCE)
	jrtangle $(SOURCE)

sortmail.pdf: $(TEXISOURCE)
	texi2dvi --pdf --batch --build-dir=sortmail.t2p -o sortmail.pdf sortmail.texi

pdf: sortmail.pdf sortmail-fop.pdf

html: sortmail.html

xml: sortmail.xml

info: sortmail.info

sortmail.html: $(TEXISOURCE)
	makeinfo --no-split --html $(TEXISOURCE)

sortmail.xml: $(TEXISOURCE)
	makeinfo --no-split --docbook $(TEXISOURCE)

sortmail.info: $(TEXISOURCE)
	makeinfo --no-split $(TEXISOURCE)

sortmail-fop.pdf: sortmail.xml
	fop -xml sortmail.xml -pdf sortmail-fop.pdf -xsl /usr/share/xml/docbook/stylesheet/docbook-xsl/fo/docbook.xsl

clean:
	rm -fr sortmail*.pdf sortmail.t2p sortmail.texi sortmail.html sortmail.info sortmail.xml
