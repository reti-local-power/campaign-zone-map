### Demonstration Analysis

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


# 1. Read in files ------------------------------------------------------------

index <- st_read("dat/suitability index/boro_suitability_index.shp")

hotspots <- st_read("dat/boro_Heatmap/campaignzones_halfmile_simple.shp")
hotspots_qtr <- st_read("dat/boro_Heatmap/campaignzones_qtrmile.shp")


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

# interactive map 
tmap_mode("view")
tmap_options(check.and.fix = TRUE)

pal <- c(brewer.pal(10, "Set3"), brewer.pal(3, "Set1"))

# # quick map look - are the hotspots flagging areas identified by the blobs?
# tm_shape(index_hp) + 
#   tm_fill("cz_num", palette = pal, style = "cat") 


# 3. Create combined shapefile with half and quarter mile hotspot shapes -------

glimpse(hotspots_qtr)
glimpse(hotspots2)

hotspots_qtr2 <- hotspots_qtr %>% 
  st_join(select(hotspots2, cz_num, geometry), join = st_intersects) %>%
  rename(czfoc_num = fid,
         in_cz = DN)

# tm_shape(hotspots2) + 
#   tm_fill("cz_num", style = "cat") + 
#   tm_shape(hotspots_qtr2) + 
#   tm_polygons("czfoc_num")

# for simplicity, remove the quarter mile clusters that don't overlap with halfmile ones

hotspots_qtr3 <- hotspots_qtr2 %>%
  filter(!is.na(cz_num))

hotspots_comp <- bind_rows(hotspots2, hotspots_qtr3) %>%
  mutate(cat = ifelse(is.na(czfoc_num), "campaign zone", "focus area"))

# check out how the combined record looks with
tm_shape(hotspots_comp) + 
  tm_fill("purple", alpha = 0.5)

# 4. Save permanent file ------------------------------------------------------

# check: var names must be no more than 10 characters
names(index_hp) %>%
  as.data.frame() %>%
  mutate(nchar = nchar(.)) %>%
  arrange(desc(nchar))

names(hotspots_comp) %>%
  as.data.frame() %>%
  mutate(nchar = nchar(.)) %>%
  arrange(desc(nchar))

# buildings flagged by hotspots (now using campaign zones)
st_write(index_hp, "dat/suitability index/boro_suitability_index_hotspot.shp", delete_dsn = T)

# hotspots/campaign zones with overlay of focus areas
st_write(hotspots_comp, "dat/boro_Heatmap/campaign_zones.shp", delete_dsn = T)

