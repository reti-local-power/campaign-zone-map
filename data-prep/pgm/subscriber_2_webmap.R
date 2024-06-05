### Subscriber Analysis

### 2. Output files for web-mapping

# The PURPOSE of this .R script is to save permanent subscriber file in a format 
# that is suitable for web mapping using javascript. Most mapping files need to be
# saved in .geojson formats.

# 0. Packages -----------------------------------------------------------------

library(tidyverse)
library(janitor)
library(sf)
library(tmap)

tmap_mode("view")
tmap_options(check.and.fix = TRUE)


# 1. Read in files ------------------------------------------------------------

subscriber <- st_read("dat/subscriber areas/subscriber_attributes.shp")

subscriber_nyc <- st_read("dat/subscriber areas/subscriber_attributes_nyc.shp")


# 2. Clean BK file ------------------------------------------------------------

subscriber2 <- subscriber %>%
  filter(dac_cat != "None") %>%
  # rename dac category names
  mutate(dac_cat = case_when(
    dac_cat == "Both DAC" ~ "State & Federal DAC",
    dac_cat == "CEJST DAC" ~ "Federal DAC only",
    dac_cat == "NYSERDA DAC" ~ "State DAC only"
  ),
         color = case_when(
    dac_cat == "State & Federal DAC" ~ "#80d366",
    dac_cat == "Federal DAC only" ~ "#fff400",
    dac_cat == "State DAC only" ~ "#00b2cb"
         )) %>%
  select(dac_cat, color, geometry) %>%
  st_transform(st_crs(4326))

# # visual check - how does this look (commented out to avoid re-running every time)
# tm_shape(subscriber2) + 
  # tm_fill("dac_cat", palette = c("#fff400", "#80d366", "#00b2cb"))

# check the CRS
st_crs(subscriber2) == st_crs(4326)

# 3. Clean NYC file -----------------------------------------------------------

subscriber2_nyc <- subscriber_nyc %>%
  filter(dac_cat != "None") %>%
  # rename dac category names
  mutate(dac_cat = case_when(
    dac_cat == "Both DAC" ~ "State & Federal DAC",
    dac_cat == "CEJST DAC" ~ "Federal DAC only",
    dac_cat == "NYSERDA DAC" ~ "State DAC only"
  ),
  color = case_when(
    dac_cat == "State & Federal DAC" ~ "#80d366",
    dac_cat == "Federal DAC only" ~ "#fff400",
    dac_cat == "State DAC only" ~ "#00b2cb"
  )) %>%
  select(dac_cat, color, geometry) %>%
  st_transform(st_crs(4326))

# # visual check - how does this look (commented out to avoid re-running every time)
# tm_shape(subscriber2_nyc) +
# tm_fill("dac_cat", palette = c("#fff400", "#80d366", "#00b2cb"))

# check the CRS
st_crs(subscriber2_nyc) == st_crs(4326)


# 4. Save permanent file ------------------------------------------------------

st_write(subscriber2, "dat/for-web-map/subscriber.geojson", delete_dsn = T)
st_write(subscriber2_nyc, "dat/for-web-map/subscriber_nyc.geojson", delete_dsn = T)

