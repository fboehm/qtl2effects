params <-
list(lastmod = structure(1573569638.25674, class = c("POSIXct", 
"POSIXt"), tzone = ""))

## ------------------------------------------------------------------------
library(TIMBR)
library(dplyr)


## ----read-csv------------------------------------------------------------
tt <- read.csv("../data/neto_traits_by_probe3_annotated.csv")
neto <- tt %>%
  tidyr::pivot_longer(cols = V2:V35, values_to = "trait", names_to = "trait_name") %>%
  dplyr::filter(!is.na(trait)) %>%
  dplyr::select(- trait_name, - neto.n, - row, - n.traits, - cM, -hs, - chr)
neto_plus <- tt %>%
  tidyr::pivot_longer(cols = V2:V35, values_to = "trait", names_to = "trait_name") %>%
  dplyr::filter(!is.na(trait)) %>%
  dplyr::select(- trait_name)


## ----load-genotypes------------------------------------------------------
if (!file.exists("../data/genotypes_array.rds")){
  fns <- dir("../data/36-state-genotypes")
  geno <- list()
  for (i in seq_along(fns)){
    load(file.path("../data/36-state-genotypes", fns[i]))
    geno[[i]] <- prsmth
  }
  names(geno) <- stringr::str_split_fixed(fns, ".genotype.probs.Rdata", 2)[, 1]
  g_transposed <- lapply(X = geno, FUN = t)
  ga <- do.call(abind::abind,c(g_transposed,list(along=0))) # 
  saveRDS(ga, "../data/genotypes_array.rds")
}
ga <- readRDS("../data/genotypes_array.rds")


## ----prior_M-define------------------------------------------------------
##### From GK example code
# Specify allelic series prior
# Suggested by Wes
# Influences how much prior weight it places on more or less complicated allelic series
prior_M <- list(model.type = "crp", # crp - Chinese Restaurant Process
                prior.alpha.type = "gamma",
                prior.alpha.shape = 1,
                prior.alpha.rate = 2.333415)


## ----load-hot------------------------------------------------------------
if (!file.exists("../data/tnseq-traits.rds")) {
  load("../data/combined_hotspot_traits.Rdata")
  saveRDS(pheno, "../data/tnseq-traits.rds")
  pheno -> tnseq_traits
} else {
  tnseq_traits <- readRDS("../data/tnseq-traits.rds")
}


## ----load-covariates-----------------------------------------------------
load("../data/reduced_map_qtl2_mapping_objects.Rdata")


## ----load-data-timbr-----------------------------------------------------
data(mcv.data) # get A matrix


## ----make_neto_list------------------------------------------------------
neto_list <- apply(FUN = as.list, X = neto, MARGIN = 1)
neto_small <- neto_list[1:3]


## ------------------------------------------------------------------------
outfn <- "../data/timbr-tnseq-results-neto.rds"
# ensure that inputs to call_timbr all have subjects in same order!
subject_ids <- rownames(tnseq_traits)
indices_addcovar <- match(subject_ids, rownames(addcovar))
addcovar <- addcovar[indices_addcovar, ]
##
indices_gp <- match(subject_ids, rownames(ga))
gp <- ga[indices_gp, , ]
##
if (!file.exists(outfn)){
  timbr_out <- parallel::mclapply(neto_list, 
#  timbr_out <- lapply(neto_small, 
                                  FUN = qtl2effects::call_timbr, 
                                  mc.cores = parallel::detectCores(),
                                  traits_df = tnseq_traits,
                                  prior_M = prior_M, 
                                  genoprobs_array = gp,
                                  addcovar = addcovar
                                  )
  saveRDS(timbr_out, outfn)
}


## ----read_timbr_results--------------------------------------------------
timbr_out <- readRDS(outfn)


## ---- annotation-tibble--------------------------------------------------
(hot_indices <- neto_plus %>%
  dplyr::group_by(hs) %>%
  dplyr::tally() %>%
  dplyr::mutate(end = cumsum(n)) %>%
  dplyr::mutate(start = 1L + end - n)
)


## ----save-files----------------------------------------------------------
purrr::pmap(.l = hot_indices, 
            .f = function(x){
              outfn = paste0( "../data/timbr-tnseq-results-neto-hs", hs, ".rds")
              saveRDS(timbr_out[start:end], outfn)
              }
            )

