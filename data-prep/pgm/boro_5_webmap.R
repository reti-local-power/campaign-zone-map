### Demonstration Analysis

### 5. Output files for web-mapping

# The PURPOSE of this .R script is to save permanent files in a format that is
# suitable for web mapping using javascript. Most mapping files need to be
# saved in .geojson formats. This script also saves copies of some descriptive
# mapping layers as .geojson, including IBZ and BID borders.

# 0. Packages -----------------------------------------------------------------

library(tidyverse)
library(janitor)
library(sf)
library(tmap)

tmap_mode("view")
tmap_options(check.and.fix = TRUE)


# 1. Read in files ------------------------------------------------------------

# final building information files
bldg <- st_read("dat/suitability index/boro_analysis.shp")

# campaign zone files
cz <- st_read("dat/boro_Heatmap/campaignzones_halfmile_simple.shp")

cz_data <- read_csv("cz summary statistics.csv") %>%
  filter(!cz_num %in% c("All", "Not in a CZ")) %>%
  mutate(cz_num = as.numeric(cz_num)) %>%
  arrange(cz_num)

# ibz
ibz_temp <- tempfile()
ibz_temp2 <- tempfile()

download.file("https://edc.nyc/sites/default/files/2020-10/IBZ%20Shapefiles.zip", ibz_temp)

unzip(ibz_temp, exdir = ibz_temp2)

ibz <- st_read(ibz_temp2)

# bid
bid <- st_read("https://data.cityofnewyork.us/resource/7jdm-inj8.geojson")



# 2. Simplify and clean up datasets -------------------------------------------

# bldg file does not need all the flag variables (f_*), nor does it need the hpd 
#  owner contact info (*_name and *_add)

bldg2 <- bldg %>%
  mutate(campzone = replace_na(campzone, "Not in a campaign zone")) %>%
  select(-starts_with("f_"), #remove flag vars (only need the final index score)
         -ends_with("_name"), -ends_with("_add"), #remove hpd owner contact info
         -zonedist1, resfarrat) %>%
  st_transform(st_crs(4326))

cz2 <- cz %>%
  mutate(campzone = case_when(
    fid == "1"  ~ "Greenpoint IBZ",
    fid == "2"  ~ "North Brooklyn Waterfront",
    fid == "3"  ~ "Flushing Ave/North Brooklyn IBZ",
    fid == "4"  ~ "Fort Greene/BK Navy Yard",
    fid == "5"  ~ "Red Hook",
    fid == "6"  ~ "East New York IBZ",
    fid == "7"  ~ "Crown Heights - Utica Ave",
    fid == "8"  ~ "East New York - Flatlands IBZ",
    fid == "9"  ~ "Canarsie - Flatlands IBZ",
    fid == "10" ~ "Sunset Park",
    fid == "11" ~ "Prospect Park South",
    fid == "12" ~ "Sheepshead Bay - Nostrand Houses",)) %>%
  select(cz_num = fid, campzone, geometry) %>%
  left_join(cz_data, by = "cz_num") %>%
  #transform to WSG 84 lat/lon information
  st_transform(st_crs(4326)) %>%
  clean_names()
  

# # check that numbering matches
# tm_shape(cz2) + 
#   tm_fill("purple")


ibz2 <- ibz %>%
  clean_names() %>%
  filter(boroname == "Brooklyn") %>%
  mutate(ibz_name = paste0(name, " IBZ")) %>%
  select(ibz_name, geometry) %>%
  #transform to WSG 84 lat/lon information
  st_transform(st_crs(4326))

# # check that the list is comprehensive 
# tm_shape(ibz2) + 
#   tm_fill("grey30")


bid2 <- bid %>%
  filter(f_all_bi_1 == "Brooklyn") %>%
  select(bid_name = f_all_bi_2, geometry)
# note that this layer is already in the right CRS so no need to transform


# 3. Save in geojson format for web mapping -----------------------------------

# building information file
st_write(bldg2, "dat/for-web-map/bldg.geojson", delete_dsn = T)

# campaign zone information file
st_write(cz2, "dat/for-web-map/cz.geojson", delete_dsn = T)

# ibz file
st_write(ibz2, "dat/for-web-map/ibz.geojson", delete_dsn = T)

# bid file
st_write(bid2, "dat/for-web-map/bid.geojson", delete_dsn = T)

