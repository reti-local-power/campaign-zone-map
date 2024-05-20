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
library(rmapshaper)

tmap_mode("view")
tmap_options(check.and.fix = TRUE)


# 1. Read in files ------------------------------------------------------------

# final building information files
bldg <- st_read("dat/suitability index/boro_analysis.shp")

# campaign zone files
cz <- st_read("dat/boro_Heatmap/campaign_zones_RETIsites.geojson")

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


# Community Districts
cd <- st_read("https://data.cityofnewyork.us/resource/jp9i-3b7y.geojson") %>%
  filter(str_sub(boro_cd, 1, 1) == "3") #restrict to just Brooklyn CDs

# City Council Districts
council <- st_read("https://data.cityofnewyork.us/resource/s2hu-y8ab.geojson") %>%
  #filter to Brooklyn Council Districts
  filter(as.numeric(coun_dist) > 33 &
           as.numeric(coun_dist) < 49)


# 2. Simplify and clean up datasets -------------------------------------------

# bldg file does not need all the flag variables (f_*), nor does it need the hpd 
#  owner contact info (*_name and *_add)

bldg2 <- bldg %>%
  mutate(campzone = replace_na(campzone, "Not in a campaign zone")) %>%
  select(-starts_with("f_"), #remove flag vars (only need the final index score)
         -ends_with("_name"), -ends_with("_add"), #remove hpd owner contact info
         -zonedist1, resfarrat) %>%
  st_transform(st_crs(4326))%>%
  distinct(bin, .keep_all = T)

# need to add centroid lat and lon for each building
## this is necessary for constructing the request for streetview image
bldg_centroid <- bldg2 %>%
  st_centroid() %>%
  st_transform(st_crs(4326)) %>%
  mutate(centroid_lon = st_coordinates(.)[,1],
         centroid_lat = st_coordinates(.)[,2]) %>%
  st_drop_geometry() %>%
  select(bin, centroid_lon, centroid_lat) 

# use simplifying algorithm to keep the building file size at a reasonable level
bldg3 <- bldg2 %>%
  ms_simplify(keep = 0.5, keep_shapes = FALSE) %>%
  full_join(bldg_centroid, by = "bin")

## compare shapes, they should look mostly the same
# tm_shape(bldg2) + 
#   tm_borders('red') + 
#   tm_shape(bldg3) + 
#   tm_fill('lightblue') + 
#   tm_borders('blue')


cz2 <- cz %>%
  mutate(campzone = case_when(
    fid == 1  ~ "Greenpoint IBZ",
    fid == 2  ~ "North Brooklyn Waterfront",
    fid == 3  ~ "Downtown BK/Naby Yard/North Brooklyn IBZ",
    fid == 4  ~ "Red Hook/Gowanus",
    fid == 5  ~ "East New York IBZ",
    fid == 6  ~ "East New York - Flatlands IBZ",
    fid == 7  ~ "Canarsie - Flatlands IBZ",
    fid == 8  ~ "Starrett City",
    fid == 9 ~ "Prospect Park South",
    fid == 10  ~ "Sunset Park",
    fid == 11 ~ "Sheepshead Bay - Nostrand Houses",
  )) %>%
  select(cz_num = fid, campzone, geometry) %>%
  left_join(cz_data, by = "cz_num") %>%
  #transform to WSG 84 lat/lon information
  st_transform(st_crs(4326)) %>%
  clean_names()

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
st_write(bldg3, "dat/for-web-map/bldg.geojson", delete_dsn = T)

# campaign zone information file
st_write(cz2, "dat/for-web-map/cz.geojson", delete_dsn = T)

# ibz file
st_write(ibz2, "dat/for-web-map/ibz.geojson", delete_dsn = T)

# bid file
st_write(bid2, "dat/for-web-map/bid.geojson", delete_dsn = T)

# cd file
cd %>% 
  select(-starts_with("shape_")) %>%
  st_write("dat/for-web-map/cd.geojson", delete_dsn = T)

# council file
council %>%
  select(-starts_with("shape_")) %>%
  st_write("dat/for-web-map/council.geojson", delete_dsn = T)
