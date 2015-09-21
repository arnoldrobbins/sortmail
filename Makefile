SOURCE = sortmail.twjr
TEXISOURCE = sortmail.texi

all: sortmail.awk sortmail.pdf

$(TEXISOURCE): $(SOURCE)
	jrweave $(SOURCE) > $(TEXISOURCE)

sortmail.awk: $(SOURCE)
	jrtangle $(SOURCE)

sortmail.pdf: $(TEXISOURCE)
	texi2dvi --pdf --batch --build-dir=sortmail.t2p -o sortmail.pdf sortmail.texi

html: sortmail.html

sortmail.html: $(TEXISOURCE)
	makeinfo --no-split --html $(TEXISOURCE)
