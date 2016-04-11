SOURCE = sortmail.twjr
TEXISOURCE = sortmail.texi

all: sortmail.awk pdf html

$(TEXISOURCE): $(SOURCE)
	jrweave $(SOURCE) > $(TEXISOURCE)

sortmail.awk: $(SOURCE)
	jrtangle $(SOURCE)

sortmail.pdf: $(TEXISOURCE)
	texi2dvi --pdf --batch --build-dir=sortmail.t2p -o sortmail.pdf sortmail.texi

pdf: sortmail.pdf

html: sortmail.html

sortmail.html: $(TEXISOURCE)
	makeinfo --no-split --html $(TEXISOURCE)

clean:
	rm -fr sortmail.pdf sortmail.t2p sortmail.texi sortmail.html
