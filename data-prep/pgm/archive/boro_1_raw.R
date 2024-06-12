### Borough-wide Analysis 
### 1. Site Identification File Setup

# The PURPOSE of this .R script is to set up the dataset for identifying
# potential solar sites and clusters across Brooklyn.

# This script is slow as it reads in large citywide files. To streamline code,
# analysis happens in the next script.

# 0. Packages -----------------------------------------------------------------

library(units)
library(tidyverse)
library(janitor)
library(clipr)
library(sf)
library(tmap)


# 1. Read in data -------------------------------------------------------------

# read in from Open Data API, takes a long time to read in
bf_raw <- st_read("https://data.cityofnewyork.us/resource/qb5r-6dgf.geojson?$LIMIT=9999999")



# NYCHA bbls associated with RETI projects
## use nycdb data to pull all NYCHA BBLs, and then restrict to the 3 campuses that
## RETI Center is working with (Red Hook East, Red Hook West, & Marcy)
## source: https://github.com/nycdb/nycdb/blob/main/src/nycdb/datasets/nycha_bbls.yml
nychabbls <- read_csv("https://raw.githubusercontent.com/JustFixNYC/nycha-scraper/098bd8232bee2cd59266bf278e26e32bd0cd7df1/Block-and-Lot-Guide-08272018.csv") %>%
  clean_names() %>%
  filter(development %in% c("RED HOOK EAST", "RED HOOK WEST", "MARCY")) %>%
  mutate(bbl = paste0("3", str_pad(block, 5, "left", "0"), str_pad(lot, 4, "left", "0"))) %>%
  # remove non-housing bbl's
  filter(is.na(facility))

nychabbls2 <- nychabbls %>%
  left_join(bf_raw %>% select(bbl = mpluto_bbl, bin, geometry),
            by = "bbl") %>%
  distinct(bin, .keep_all = T) %>%
  st_as_sf()

# # Visual check: are all buildings on these 3 campuses included? Yes!
# tmap_mode("view")
# 
# tm_shape(nychabbls2) + 
#   tm_polygons()

# clean up for export
nychabbls3 <- nychabbls2 %>%
  select(bin, bbl, development, address, geometry)

# 2. Identify sufficiently large rooftop sites --------------------------------

glimpse(bf_raw)

# look for distinct variables
bf_raw %>%
  st_drop_geometry() %>%
  summarise_all(n_distinct)

bf <- bf_raw %>%
  st_transform(st_crs(2263)) %>%
  select(bin, bbl = base_bbl, mpluto_bbl, cnstrct_yr, heightroof) %>%
  filter(str_sub(bbl, 1, 1) == "3") %>% # keep brooklyn records only
  mutate(shape_area = st_area(.))

# check that all bbl's start with 3
bf %>%
  st_drop_geometry() %>%
  mutate(boro = str_sub(bbl, 1, 1)) %>%
  count(boro)

# filter down to sufficiently large rooftops (file is too large to save)
bf2 <- bf %>%
  filter(as.numeric(shape_area) >= 8000)


# 3. Save permanent file ------------------------------------------------------

st_write(bf2, dsn = "dat/bldg fp bk/bf.shp", delete_dsn = T)

st_write(nychabbls3, dsn = "dat/nycha/nychabbl.shp", delete_dsn = T)

