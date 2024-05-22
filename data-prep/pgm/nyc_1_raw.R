### City-wide Analysis 
### 1. Site Identification File Setup

# The PURPOSE of this .R script is to set up the dataset for identifying
# potential solar sites and clusters across all five boros of NYC.

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

# read in from Open Data API
## This takes a long time to read in
bf_raw <- st_read("https://data.cityofnewyork.us/resource/qb5r-6dgf.geojson?$LIMIT=9999999")


# read in list of BBL's associated with RETI projects
reti_projects <- read_csv("dat/reti_projects/reti_solar_projects.csv",
                          # manually set bbl as a character variable
                          col_types = list(bbl = col_character())) 

reti_projects2 <- reti_projects %>%
  left_join(bf_raw %>% select(bbl = mpluto_bbl, bin, geometry),
            by = "bbl",
            relationship = "many-to-many") %>%
  distinct(bin, .keep_all = T) %>%
  st_as_sf()

# # Visual check: are all buildings on these 3 campuses included? Yes!
# tmap_mode("view")
# 
# tm_shape(reti_projects2) + 
#   tm_polygons()

# clean up for export
reti_projects3 <- reti_projects2 %>%
  select(bin, bbl, name, address, geometry)

# 2. Identify sufficiently large rooftop sites --------------------------------

glimpse(bf_raw)

# look for distinct variables
bf_raw %>%
  st_drop_geometry() %>%
  summarise_all(n_distinct)

# construct building area using local CRS (this step takes some time)
bf <- bf_raw %>%
  st_transform(st_crs(2263)) %>%
  select(bin, bbl = base_bbl, mpluto_bbl, cnstrct_yr, heightroof) %>%
  mutate(shape_area = st_area(.))

# filter down to sufficiently large rooftops (file is too large to save)
bf2 <- bf %>%
  filter(as.numeric(shape_area) >= 8000)


# 3. Save permanent file ------------------------------------------------------

st_write(bf2, dsn = "dat/bldg fp bk/nyc_bf.shp", delete_dsn = T)

st_write(reti_projects3, dsn = "dat/reti_projects/reti_solar_projects_bf.geojson", delete_dsn = T)

