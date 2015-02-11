PLATE = 8
PLATEFILE = $(CURDIR)/plate8.tsv
BATCHDIR = ../datasets/screen/BATCH5_8/

SRCDIR = $(CURDIR)/src

RAWDIR = $(CURDIR)/raw
$(RAWDIR):
	mkdir -p $(RAWDIR)

FIXEDDIR = $(CURDIR)/fixed
$(FIXEDDIR):
	mkdir -p $(FIXEDDIR)

TIMEPOINTS = $(CURDIR)/tpoints.tsv
NAMECONVERSION = $(CURDIR)/file_conversion.txt

MISSING = $(CURDIR)/missing.txt
ADDITIONALMISSING = $(CURDIR)/additional_missing.txt

EMAP = $(CURDIR)/fileForCluster3.txt
RESCALED = $(CURDIR)/emap.matrix.txt

$(NAMECONVERSION): $(TIMEPOINTS)
	$(SRCDIR)/collect_iris $(TIMEPOINTS) $(BATCHDIR) $(RAWDIR) $(PLATE) > $(NAMECONVERSION)

$(MISSING): $(NAMECONVERSION) $(PLATEFILE)
	$(SRCDIR)/missing_colonies --size 0 --quantile 0.95 $(RAWDIR) $(PLATEFILE) > $(MISSING)
	cat $(ADDITIONALMISSING) >> $(MISSING)

RAWS = $(wildcard $(RAWDIR)/*.iris)
FIXEDS = $(foreach RAW,$(RAWS),$(addprefix $(FIXEDDIR)/,$(addsuffix .iris,$(basename $(notdir $(RAW))))))

$(FIXEDDIR)/%.iris: $(RAWDIR)/%.iris $(MISSING) $(PLATEFILE)
	$(SRCDIR)/fix_iris --circularity 0.5 --size 1200 --ignore $(MISSING) --variance 0.9 $< $(PLATEFILE) $(FIXEDDIR)

$(RESCALED): $(EMAP)
	$(SRCDIR)/rescale_sscores $(EMAP) > $(RESCALED)

collect: $(NAMECONVERSION)
pre-process: $(FIXEDS)
post-process: $(RESCALED)

.PHONY: collect pre-process post-process
