# NYCHA BBL List

# The PURPOSE of this script is to generate a .csv file with all addresses and BBL's
#  associated with NYCHA developments across New York City. This file can be used
#  as a resource by future programmers to update the list of RETI Center projects
#  that is used in the analysis of this project.

# 0. Packages -----------------------------------------------------------------

library(tidyverse)


# 1. Read in data -------------------------------------------------------------

# data for this come from the NYCDB github repository
## (https://github.com/nycdb/nycdb/blob/main/src/nycdb/datasets/nycha_bbls.yml)

nycha_bbl_all <- read_csv("https://raw.githubusercontent.com/JustFixNYC/nycha-scraper/098bd8232bee2cd59266bf278e26e32bd0cd7df1/Block-and-Lot-Guide-08272018.csv") %>%
  # remove non-residential BBLs for things like boilers and maintenance sheds
  filter(is.na(FACILITY))


# 2. Save permanent file ------------------------------------------------------

write_csv("")
