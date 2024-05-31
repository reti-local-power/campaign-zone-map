### City-wide Analysis

### 3. Hotspot Analysis

# The PURPOSE of this .R script is to conduct a hotspot analysis using the 
# Getis Ord Gi method and the sfdep package.
# This replaces the QGIS hotspot method used for the borough analysis, as
# that method overemphasized proximity and undercounted large buildings with
# higher suitability scores

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

index <- st_read("dat/suitability index/boro_suitability_index.shp")

hotspots <- st_read("dat/boro_Heatmap/campaign_zones_RETIsites.geojson")


# 2. Create hotspot flag var --------------------------------------------------

# check that CRS is the same for both
st_crs(index) == st_crs(hotspots)

# rename feature id var to make it relevant to campaign zones
hotspots2 <- hotspots %>%
  rename(cz_num = fid)

tm_shape(hotspots) + 
  tm_fill() + 
  tm_shape(hotspots2) + 
  tm_polygons()

index_hp <- index %>%
  st_join(hotspots2, join = st_intersects) %>%
  mutate(in_cz = replace_na(DN, 0))

# check frequency of new variable (should be 1 only when cz_num is not NA)
index_hp %>%
  st_drop_geometry() %>%
  count(cz_num, in_cz)


# # quick map look - are the hotspots flagging areas identified by the blobs?
# 
# pal <- c(brewer.pal(10, "Set3"), brewer.pal(3, "Set1"))
# tm_shape(index_hp) + 
#   tm_fill("cz_num", palette = pal, style = "cat") 


# 3. Save permanent file ------------------------------------------------------

# check: var names must be no more than 10 characters
names(index_hp) %>%
  as.data.frame() %>%
  mutate(nchar = nchar(.)) %>%
  arrange(desc(nchar))

# buildings flagged by hotspots (now using campaign zones)
st_write(index_hp, "dat/suitability index/boro_suitability_index_hotspot.shp", delete_dsn = T)


