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

# 1. Read in data -------------------------------------------------------------

# read in from Open Data API, takes a long time to read in
bf_raw <- st_read("https://data.cityofnewyork.us/resource/qb5r-6dgf.geojson?$LIMIT=9999999")


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

