### Citywide Analysis

### 3. Hotspot Analysis

# The PURPOSE of this .R script is to interpret the hotspot analysis done in 
# QGIS, creating a flag variable on individual buildings in the suitability 
# index file.

# The output data from this file is read into the fourth and final program
# for descriptive statistical analysis and final formatting


# 0. Packages -----------------------------------------------------------------

library(tidyverse)
library(sf)
library(spdep)
library(sfdep)
library(tmap)
library(RColorBrewer)

# interactive map 
tmap_mode("view")
tmap_options(check.and.fix = TRUE)


# 1. Read in files ------------------------------------------------------------

index <- st_read("dat/suitability index/nyc_suitability_index.shp")

hotspots <- st_read("dat/nyc_Heatmap/campaign_zones_nyc_exp.geojson")


# 2. Create hotspot flag var --------------------------------------------------

# check that CRS is the same for both
st_crs(index) == st_crs(hotspots)

# rename feature id var to make it relevant to campaign zones
hotspots2 <- hotspots %>%
  rename(cz_num = fid)

# map the hotspots to identify names for each one
tm_shape(hotspots2) + 
  tm_polygons()

# create campzone, a string naming each campaign zone
index_hp <- index %>%
  st_join(hotspots2, join = st_intersects) %>%
  mutate(in_cz = replace_na(DN, 0),
         campzone = case_when(
           cz_num == 1 ~ "Eastchester",
           cz_num == 2 ~ "Bay Plaza - Co-op City",
           cz_num == 3 ~ "Inwood",
           cz_num == 4 ~ "Claremont Park East",
           cz_num == 5 ~ "Crotona Park East",
           cz_num == 6 ~ "Highbridge - Macombs Dam",
           cz_num == 7 ~ "Soundview",
           cz_num == 8 ~ "Westchester Creek",
           cz_num == 9 ~ "Mott Haven",
           cz_num == 10 ~ "Harlem",
           cz_num == 11 ~ "Port Morris - Hunts Point",
           cz_num == 12 ~ "Rikers Island",
           cz_num == 13 ~ "College Point",
           cz_num == 14 ~ "Colleg Point - Whitestone",
           cz_num == 15 ~ "College Point South",
           cz_num == 16 ~ "Astoria",
           cz_num == 17 ~ "East Elmhurst",
           cz_num == 18 ~ "Flushing",
           cz_num == 19 ~ "Ridgewood",
           cz_num == 20 ~ "Jamaica/St. Albans",
           cz_num == 21 ~ "Navy Yard - North Brooklyn IBZ - Sunnywide",
           cz_num == 23 ~ "Red Hook - Governor's Island",
           cz_num == 24 ~ "Ocean Hill - Brownsville",
           cz_num == 25 ~ "JFK 1",
           cz_num == 26 ~ "JFK 2",
           cz_num == 27 ~ "JFK 3",
           cz_num == 28 ~ "East New York - Flatlands IBZ",
           cz_num == 29 ~ "Canarsie - Flatlands IBZ",
           cz_num == 30 ~ "JFK 4",
           cz_num == 31 ~ "Gowanus - Sunset Park",
           cz_num == 32 ~ "Port Richmond - West Brighton",
           cz_num == 33 ~ "Mariners Harbor - Portside",
           cz_num == 34 ~ "Bath Beach",
           cz_num == 35 ~ "Gravesend",)
  )

# check frequency of new variable (should be 1 only when cz_num is not NA)
index_hp %>%
  st_drop_geometry() %>%
  count(cz_num, campzone, in_cz)

# map the campzone variable, the name in the legend should match up roughly with the neighborhood name
tmap_options(max.categories = 40)

tm_shape(index_hp) + 
  tm_fill("campzone")


# 3. Save permanent file ------------------------------------------------------

# check: var names must be no more than 10 characters
names(index_hp) %>%
  as.data.frame() %>%
  mutate(nchar = nchar(.)) %>%
  arrange(desc(nchar))

# buildings flagged by hotspots (now using campaign zones)
st_write(index_hp, "dat/suitability index/nyc_suitability_index_hotspot.shp", delete_dsn = T)


