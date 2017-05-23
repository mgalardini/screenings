BATCH = batch6
IRIS = iris_0.9.4.71

MINSIZE = 1900
MAXSIZE = 1700
COLOR = 

PLATE = 8
PLATEFILE = $(CURDIR)/plates.tsv
BATCHDIR = $(CURDIR)/BATCH6/

SRCDIR = $(CURDIR)/src
NOTEBOOKSDIR = $(CURDIR)/notebooks

RAWDIR = $(CURDIR)/$(BATCH).raw
ifeq ($(COLOR),--color)
  RAWDIR=$(CURDIR)/$(BATCH).raw.color
endif
$(RAWDIR):
	mkdir -p $(RAWDIR)

FIXEDDIR = $(CURDIR)/fixed/$(BATCH)
ifeq ($(COLOR),--color)
  FIXEDDIR=$(CURDIR)/fixed.color/$(BATCH).color
endif
$(FIXEDDIR):
	mkdir -p $(FIXEDDIR)

TIMEPOINTS = $(CURDIR)/$(BATCH).tpoints.tsv
NAMECONVERSION = $(CURDIR)/$(BATCH).file_conversion.txt

MISSING = $(CURDIR)/$(BATCH).missing.txt
ADDITIONALMISSING = $(CURDIR)/$(BATCH).additional_missing.txt

SEQUENCED = $(CURDIR)/sequenced.txt
REMOVE = $(CURDIR)/removed_conditions.txt

EMAP = $(CURDIR)/fileForCluster3.txt
RENAMED = $(CURDIR)/fileForCluster3.renamed.txt
RENAMED2 = $(CURDIR)/fileForCluster3.renamed2.txt
RESTRICTED = $(CURDIR)/fileForCluster3.restricted.txt
RESCALED = $(CURDIR)/fileForCluster3.rescaled.txt
MERGED = $(CURDIR)/emap.matrix.txt
FDR = $(CURDIR)/emap.fdr.txt
FDRBINARY = $(CURDIR)/emap.binary.txt
PHENODIR = $(CURDIR)/phenotypes
$(PHENODIR):
	mkdir -p $(PHENODIR)
BPHENODIR = $(CURDIR)/binary_phenotypes
$(BPHENODIR):
	mkdir -p $(BPHENODIR)

# Phenotypes still separated by plate
ARESCALED = $(CURDIR)/fileForCluster3.all.rescaled.txt
AMERGED = $(CURDIR)/emap.matrix.all.txt
AFDR = $(CURDIR)/emap.fdr.all.txt

# Name conversion
CONVERSION = $(CURDIR)/conditions.csv

# External data: deletion screen
DELDIR = $(CURDIR)/deletion_screen
DELOUT = $(CURDIR)/deletion_screen_out
$(DELOUT):
	mkdir -p $(DELOUT)
DELIN = $(DELDIR)/Cleaner_NormScores_joinedConds.txt
DEL = $(DELOUT)/deletion.matrix.txt
DELFDR = $(DELOUT)/deletion.fdr.txt
DELGENES = $(DELOUT)/deletion.genes.2.txt
DELREMOVE = $(DELOUT)/ignored_genes.txt
DELALLIN = $(DELDIR)/all_genes_matched_and_joined_New_NT.txt
DELALL = $(DELOUT)/deletion.all.matrix.txt
DELALLFDR = $(DELOUT)/deletion.all.fdr.txt
DELALLGENES = $(DELOUT)/deletion.all.genes.2.txt
DELALLGENES50 = $(DELOUT)/deletion.all.genes.50.txt
DELALLGENES10 = $(DELOUT)/deletion.all.genes.10.txt
DELALLGENES5 = $(DELOUT)/deletion.all.genes.5.txt
DELALLCLUSTERS = $(DELOUT)/deletion.all.clusters.txt

# Merging conditions
SHARED = $(DELDIR)/shared_conditions.txt
MERGEDDIR = $(CURDIR)/merged
$(MERGEDDIR):
	mkdir -p $(MERGEDDIR)
MERGEDGENES = $(DELOUT)/merged.genes.freq.2.txt
MERGEDGENES5 = $(DELOUT)/merged.genes.freq.5.txt
MERGEDGENES10 = $(DELOUT)/merged.genes.freq.10.txt
MERGEDGENES50 = $(DELOUT)/merged.genes.freq.50.txt
MERGEDGENESUNION = $(DELOUT)/merged.genes.union.2.txt
MERGEDGENESUNION5 = $(DELOUT)/merged.genes.union.5.txt
MERGEDGENESUNION10 = $(DELOUT)/merged.genes.union.10.txt
MERGEDGENESUNION50 = $(DELOUT)/merged.genes.union.50.txt

########################
## Select time points ##
########################

ifeq ($(COLOR),--color)
  TIMEPOINTS=$(CURDIR)/$(BATCH).tpoints.color.tsv
endif

ifeq ($(BATCH),batch5)
  SELECT1=find $(BATCHDIR) -name '*.iris' | grep $(IRIS) | grep -v Keio | $(SRCDIR)/get_time_points_$(BATCH) - --size-min $(MINSIZE) --size-max $(MAXSIZE) $(COLOR) > $(TIMEPOINTS)
  SELECT2=echo "nothing to be done here"
  JOIN=echo "nothing to be done here"
else
  SELECT1=find $(BATCHDIR) -name '*.iris' | grep $(IRIS) | $(SRCDIR)/get_time_points_$(BATCH) - --exclude 10_A --exclude 10_B --exclude 10_C --size-min 1900 --size-max 1700 $(COLOR) > $(TIMEPOINTS).89
  SELECT2=find $(BATCHDIR) -name '*.iris' | grep $(IRIS) | $(SRCDIR)/get_time_points_$(BATCH) - --exclude 9_A --exclude 9_B --exclude 9_C --exclude 8_A --exclude 8_B --exclude 8_C --size-min 1300 --size-max 2300 $(COLOR) > $(TIMEPOINTS).10
  JOIN=$(SRCDIR)/fix_batch6 $(TIMEPOINTS).89 $(TIMEPOINTS).10 > $(TIMEPOINTS)
endif

$(TIMEPOINTS): $(BATCHDIR)
	$(SELECT1)
	$(SELECT2)
	$(JOIN)

#############
## Collect ##
#############

ifeq ($(COLOR),--color)
  NAMECONVERSION=$(CURDIR)/$(BATCH).file_conversion.color.txt
endif

$(NAMECONVERSION): $(TIMEPOINTS) $(RAWDIR)
	$(SRCDIR)/collect_iris_$(BATCH) $(TIMEPOINTS) $(BATCHDIR) $(RAWDIR) $(PLATE) $(IRIS) > $(NAMECONVERSION)

####################
## Pre-processing ##
####################

$(MISSING): $(NAMECONVERSION) $(PLATEFILE)
	$(SRCDIR)/missing_colonies --size 0 --percentile 0.66 $(RAWDIR) $(PLATEFILE) > $(MISSING)
	cat $(ADDITIONALMISSING) >> $(MISSING)

RAWS = $(wildcard $(RAWDIR)/*.iris)
FIXEDS = $(foreach RAW,$(RAWS),$(addprefix $(FIXEDDIR)/,$(addsuffix .iris,$(basename $(notdir $(RAW))))))

$(FIXEDDIR)/%.iris: $(RAWDIR)/%.iris $(MISSING) $(PLATEFILE) $(FIXEDDIR)
	$(SRCDIR)/fix_iris --circularity1 0.5 --size 1000 --circularity2 0.3 --ignore $(MISSING) --variance-size 0.9 --variance-circularity 0.95 $< $(PLATEFILE) $(FIXEDDIR) 

######################
## Post-processing  ##
######################

$(RENAMED): $(EMAP)
	$(SRCDIR)/rename_matrix $(EMAP) $(CONVERSION) $(RENAMED)
$(RENAMED2): $(RENAMED) $(REMOVED)
	$(SRCDIR)/remove_conditions $< $(REMOVE) $@

$(MERGED): $(AMERGED)
	$(SRCDIR)/remove_strains $< $(SEQUENCED) $@

$(FDR): $(AFDR) $(MERGED) $(PHENODIR) $(BPHENODIR)
	$(SRCDIR)/remove_strains $< $(SEQUENCED) $@ && \
	$(SRCDIR)/get_phenotypes $(MERGED) $@ $(PHENODIR) --threshold 0.05 && \
	$(SRCDIR)/get_phenotypes $(MERGED) $@ $(BPHENODIR) --binary --threshold 0.05

$(FDRBINARY): $(MERGED) $(FDR)
	$(SRCDIR)/get_binary_matrix $(MERGED) $(FDR) --separator ',' > $(FDRBINARY)

$(ARESCALED): $(RENAMED2)
	$(SRCDIR)/rescale_sscores $< > $@

$(AMERGED): $(ARESCALED)
	$(SRCDIR)/merge_columns $< > $@

$(AFDR): $(AMERGED)
	$(SRCDIR)/fdr_matrix $(AMERGED) $(AFDR)

######################################
## Deletion screen post-processing  ##
######################################

$(DEL): $(DELIN) $(DELOUT)
	$(SRCDIR)/remove_duplicates $< $@

$(DELFDR): $(DEL)
	$(SRCDIR)/fdr_matrix $(DEL) $(DELFDR)

$(DELGENES): $(DEL) $(DELFDR) $(SHARED)
	$(SRCDIR)/important_genes $(DEL) $(DELFDR) $(SHARED) --filter Deletion > $(DELGENES)

$(DELREMOVE): $(DELIN)
	$(SRCDIR)/discard_genes $< | awk '{print $$1}' | sort | uniq > $@

$(DELALL): $(DELALLIN) $(DELOUT)
	$(SRCDIR)/remove_duplicates $< $@

$(DELALLFDR): $(DELALL)
	$(SRCDIR)/fdr_matrix $(DELALL) $(DELALLFDR)

$(DELALLGENES): $(DELALL) $(DELALLFDR) $(DELREMOVE)
	$(SRCDIR)/important_genes $(DELALL) $(DELALLFDR) $(SHARED) --negative --no-filter --ignore $(DELREMOVE) > $(DELALLGENES)

$(DELALLGENES5): $(DELALL) $(DELALLFDR) $(DELREMOVE)
	$(SRCDIR)/important_genes $(DELALL) $(DELALLFDR) $(SHARED) --negative --no-filter --threshold 5E-5 --ignore $(DELREMOVE) > $(DELALLGENES5)

$(DELALLGENES10): $(DELALL) $(DELALLFDR) $(DELREMOVE)
	$(SRCDIR)/important_genes $(DELALL) $(DELALLFDR) $(SHARED) --negative --no-filter --threshold 5E-10 --ignore $(DELREMOVE) > $(DELALLGENES10)

$(DELALLGENES50): $(DELALL) $(DELALLFDR) $(DELREMOVE)
	$(SRCDIR)/important_genes $(DELALL) $(DELALLFDR) $(SHARED) --negative --no-filter --threshold 5E-50 --ignore $(DELREMOVE) > $(DELALLGENES50)

##############################################
## Merge conditions using chemical genomics ##
##############################################

$(DELALLCLUSTERS): $(DELALL)
	$(SRCDIR)/do_correlation $(DELALL) deletion.all.correlation.txt --filter --pearson --columns
	$(SRCDIR)/get_hclusters deletion.all.correlation.txt deletion.all.linkage.txt deletion.all.dendrogram.txt --iterations 100 --score 0.2 --distance > $(DELALLCLUSTERS)

$(CURDIR)/merging.done: $(DELALLCLUSTERS) $(SHARED) $(MERGEDDIR) $(MERGED)
	$(SRCDIR)/combine_conditions $(DELALLCLUSTERS) $(SHARED) $(MERGED) $(MERGEDDIR) > $@

$(MERGEDGENES): $(DELALLCLUSTERS) $(DELALLGENES)
	$(SRCDIR)/important_genes_combined $(DELALLCLUSTERS) $(DELALLGENES) $(SHARED) > $@

$(MERGEDGENES5): $(DELALLCLUSTERS) $(DELALLGENES5)
	$(SRCDIR)/important_genes_combined $(DELALLCLUSTERS) $(DELALLGENES5) $(SHARED) > $@

$(MERGEDGENES10): $(DELALLCLUSTERS) $(DELALLGENES10)
	$(SRCDIR)/important_genes_combined $(DELALLCLUSTERS) $(DELALLGENES10) $(SHARED) > $@

$(MERGEDGENES50): $(DELALLCLUSTERS) $(DELALLGENES50)
	$(SRCDIR)/important_genes_combined $(DELALLCLUSTERS) $(DELALLGENES50) $(SHARED) > $@

$(MERGEDGENESUNION): $(DELALLCLUSTERS) $(DELALLGENES)
	$(SRCDIR)/important_genes_combined $(DELALLCLUSTERS) $(DELALLGENES) $(SHARED) --merge union > $@

$(MERGEDGENESUNION5): $(DELALLCLUSTERS) $(DELALLGENES5)
	$(SRCDIR)/important_genes_combined $(DELALLCLUSTERS) $(DELALLGENES5) $(SHARED) --merge union > $@

$(MERGEDGENESUNION10): $(DELALLCLUSTERS) $(DELALLGENES10)
	$(SRCDIR)/important_genes_combined $(DELALLCLUSTERS) $(DELALLGENES10) $(SHARED) --merge union > $@

$(MERGEDGENESUNION50): $(DELALLCLUSTERS) $(DELALLGENES50)
	$(SRCDIR)/important_genes_combined $(DELALLCLUSTERS) $(DELALLGENES50) $(SHARED) --merge union > $@

select: $(TIMEPOINTS)
collect: $(NAMECONVERSION)
pre-process: $(FIXEDS)
post-process: $(MERGED) $(FDR) $(FDRBINARY) $(AFDR)
deletion: $(DEL) $(DELFDR) $(DELGENES) $(DELALL) $(DELALLFDR) $(DELALLGENES) $(DELALLGENES5) $(DELALLGENES10) $(DELALLGENES50)
clusters: $(DELALLCLUSTERS) $(CURDIR)/merging.done $(MERGEDGENES) $(MERGEDGENES5) $(MERGEDGENES10) $(MERGEDGENES50) $(MERGEDGENESUNION) $(MERGEDGENESUNION5) $(MERGEDGENESUNION10) $(MERGEDGENESUNION50)

.PHONY: select collect pre-process post-process deletion clusters
