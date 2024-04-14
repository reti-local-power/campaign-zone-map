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


# 1. Read in files ------------------------------------------------------------

# final building information files
bldg <- st_read("dat/suitability index/boro_analysis.shp")





# 2. Simplify and clean up datasets -------------------------------------------

# bldg file does not need all the flag variables (f_*), nor does it need the hpd 
#  owner contact info (*_name and *_add)

bldg2 <- bldg %>%
  select(-starts_with("f_"), #remove flag vars (only need the final index score)
         -ends_with("_name"), -ends_with("_add"), #remove hpd owner contact info
         -zonedist1, resfarrat) %>%
  st_transform(st_crs(4326))



# 3. Save in geojson format for web mapping -----------------------------------

# building information file
st_write(bldg2, "dat/for-web-map/bldg.geojson", delete_dsn = T)

