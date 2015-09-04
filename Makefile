BATCH = batch5

PLATE = 8
PLATEFILE = $(CURDIR)/$(BATCH).tsv
BATCHDIR = ../../datasets/screens/BATCH5_8/

SRCDIR = $(CURDIR)/src
NOTEBOOKSDIR = $(CURDIR)/notebooks

RAWDIR = $(CURDIR)/$(BATCH).raw
$(RAWDIR):
	mkdir -p $(RAWDIR)

FIXEDDIR = $(CURDIR)/$(BATCH).fixed
$(FIXEDDIR):
	mkdir -p $(FIXEDDIR)

TIMEPOINTS = $(CURDIR)/$(BATCH).tpoints.tsv
NAMECONVERSION = $(CURDIR)/$(BATCH).file_conversion.txt

MISSING = $(CURDIR)/$(BATCH).missing.txt
ADDITIONALMISSING = $(CURDIR)/$(BATCH).additional_missing.txt

EMAP = $(CURDIR)/$(BATCH).fileForCluster3.txt
RENAMED = $(CURDIR)/$(BATCH).fileForCluster3.renamed.txt
RESCALED = $(CURDIR)/emap.matrix.txt
FDR = $(CURDIR)/emap.fdr.txt

# Name conversion
CONVERSION = $(CURDIR)/conditions.csv

# External data
ROARY = $(CURDIR)/gene_presence_absence.csv
SNPS = $(CURDIR)/SNPs_matrix.tsv
SNPSDEL = $(CURDIR)/SNPs_del_matrix.tsv
SNPSFUNCTIONAL = $(CURDIR)/SNPs_functional_matrix.tsv

# External data: deletion screen
DELDIR = $(CURDIR)/deletion_screen
DELIN = $(DELDIR)/size_NormScores_cleaner_b45_9subB.txt
DEL = $(CURDIR)/deletion.matrix.txt
DELFDR = $(CURDIR)/deletion.fdr.txt
DELGENES = $(CURDIR)/deletion.genes.txt

#############
## Collect ##
#############

$(NAMECONVERSION): $(TIMEPOINTS) $(RAWDIR)
	$(SRCDIR)/collect_iris $(TIMEPOINTS) $(BATCHDIR) $(RAWDIR) $(PLATE) > $(NAMECONVERSION)

####################
## Pre-processing ##
####################

$(MISSING): $(NAMECONVERSION) $(PLATEFILE)
	$(SRCDIR)/missing_colonies --size 0 --percentile 0.66 $(RAWDIR) $(PLATEFILE) > $(MISSING)
	cat $(ADDITIONALMISSING) >> $(MISSING)

RAWS = $(wildcard $(RAWDIR)/*.iris)
FIXEDS = $(foreach RAW,$(RAWS),$(addprefix $(FIXEDDIR)/,$(addsuffix .iris,$(basename $(notdir $(RAW))))))

$(FIXEDDIR)/%.iris: $(RAWDIR)/%.iris $(MISSING) $(PLATEFILE) $(FIXEDDIR)
	$(SRCDIR)/fix_iris --circularity 0.5 --size 1200 --ignore $(MISSING) --variance-size 0.9 --variance-circularity 0.95 $< $(PLATEFILE) $(FIXEDDIR)

######################
## Post-processing  ##
######################

$(RENAMED): $(EMAP)
	$(SRCDIR)/rename_matrix $(EMAP) $(CONVERSION) $(RENAMED)

$(RESCALED): $(RENAMED)
	$(SRCDIR)/rescale_sscores $(RENAMED) > $(RESCALED)

$(FDR): $(RESCALED)
	$(SRCDIR)/fdr_matrix $(RESCALED) $(FDR)

######################################
## Deletion screen post-processing  ##
######################################

$(DEL): $(DELIN) $(RESCALED)
	$(SRCDIR)/shared_matrix $(DELIN) $(RESCALED) $(DEL) --index1 genes --index2 Gene

$(DELFDR): $(DEL)
	$(SRCDIR)/fdr_matrix $(DEL) $(DELFDR) --index genes

$(DELGENES): $(DEL) $(DELFDR)
	$(SRCDIR)/important_genes $(DEL) $(DELFDR) --index1 genes --index2 genes --filter Deletion > $(DELGENES)

########################
## Reports generation ##
########################

NPHENOTYPES = $(NOTEBOOKSDIR)/phenotypes.ipynb
RPHENOTYPES = $(NOTEBOOKSDIR)/phenotypes.html
$(RPHENOTYPES): $(NPHENOTYPES) $(RESCALED) $(FDR)
	runipy -o $(NPHENOTYPES) && \
	cd $(NOTEBOOKSDIR) && ipython nbconvert --to=html $(notdir $(NPHENOTYPES)) --template html.tpl && cd $(CURDIR) && \
	git add $(NPHENOTYPES) && \
	git commit -m "Updated phenotypes report" && \
	git push

NGENOTYPES = $(NOTEBOOKSDIR)/phenotypes_genetics.ipynb
RGENOTYPES = $(NOTEBOOKSDIR)/phenotypes_genetics.html
$(RGENOTYPES): $(NGENOTYPES) $(RESCALED) $(FDR) $(ROARY) $(SNPS) $(SNPSDEL) $(SNPSFUNCTIONAL)
	runipy -o $(NGENOTYPES) && \
	cd $(NOTEBOOKSDIR) && ipython nbconvert --to=html $(notdir $(NGENOTYPES)) --template html.tpl && cd $(CURDIR) && \
	git add $(NGENOTYPES) && \
	git commit -m "Updated phenotypes/genotypes report" && \
	git push

collect: $(NAMECONVERSION)
pre-process: $(FIXEDS)
post-process: $(RESCALED) $(FDR)
deletion: $(DEL) $(DELFDR) $(DELGENES)
reports: $(RPHENOTYPES) $(RGENOTYPES)

.PHONY: collect pre-process post-process deletion reports
