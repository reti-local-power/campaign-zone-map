### Citywide Analysis

### 4. Analysis and Output tables

# The PURPOSE of this .R script is to develop summary statistics based on 
# in_cz spots and site suitability scores, and to link suitability information 
# to useful outreach information.

# 0. Packages -----------------------------------------------------------------

library(units)
library(tidyverse)
library(openxlsx)
library(janitor)
library(clipr)
library(sf)
library(tidygeocoder)
library(rjson)
library(tmap)

# interactive map 
tmap_mode("view")
tmap_options(check.and.fix = TRUE)


# 1. Read in data -------------------------------------------------------------

# - index score csv
bf <- read_csv("dat/nyc_bldg_fp_index_and_elecprod.csv") %>%
  #remove duplicate variable
  select(-elcprd_MWh)

# - index score shapefile with hotspot
bf_shp <- st_read("dat/suitability index/nyc_suitability_index_hotspot.shp")

# - hotspots (for naming)
hotspots <- st_read("dat/nyc_Heatmap/campaign_zones_nyc_exp.geojson")

# - BID (helpful for final spreadsheet)
bid <- st_read("https://data.cityofnewyork.us/resource/7jdm-inj8.geojson")

# - IBZ (helpful for final spreadsheet)
ibz_temp <- tempfile()
ibz_temp2 <- tempfile()

download.file("https://edc.nyc/sites/default/files/2020-10/IBZ%20Shapefiles.zip", ibz_temp)

unzip(ibz_temp, exdir = ibz_temp2)

ibz <- st_read(ibz_temp2)

# - Community Districts (helpful for final spreadsheet)
cd <- st_read("https://data.cityofnewyork.us/resource/jp9i-3b7y.geojson") 

# - City Council Districts (helpful for final spreadsheet)
council <- st_read("https://data.cityofnewyork.us/resource/s2hu-y8ab.geojson") 


# 2. Join data together -------------------------------------------------------

# identify duplicated variables to remove before joining
compare_df_cols(bf, bf_shp) %>% 
  as.data.frame() %>% 
  filter(!is.na(bf) & !is.na(bf_shp) & column_name != "bin") %>%
  pull(column_name)

# clean up the hotspot outputted variables to keep only the relevant ones
bf_shp2 <- bf_shp %>%
  select(bin, near_reti, cz_num, in_cz)

joined <- bf %>%
  mutate(bin = as.character(bin)) %>%
  left_join(bf_shp2, by = "bin") %>%
  mutate(ratio_residfar = ifelse(is.infinite(ratio_residfar), NA, ratio_residfar)) %>%
  st_as_sf() %>%
  # there are 42 rows that aren't in the shapefile layer, remove them
  filter(!st_is_empty(.))

joined %>% st_drop_geometry() %>%
  count(in_cz)


# 3. Generate summary statistics ----------------------------------------------
# calculate the statistics relevant to the memo for RETI Center

# number of hotspot buildings out of total
joined %>% st_drop_geometry() %>% count(in_cz)
nrow(joined)


# average suitability score for hotspot buildings
joined %>% 
  st_drop_geometry() %>%
  group_by(in_cz) %>%
  summarise(n = n(),
            avg_index = mean(index))

joined %>% 
  st_drop_geometry() %>%
  summarise(avg_index = mean(index))

# buildings with an 8 or higher suitability index score
joined %>%
  st_drop_geometry() %>%
  mutate(index_ge8 = ifelse(index >= 8, 1, 0)) %>%
  count(index_ge8)

# percent of 8+ scoring buildings inside vs outside hotspot
joined %>%
  st_drop_geometry() %>%
  filter(index >= 8) %>%
  count(in_cz) %>%
  mutate(pct = n/sum(n))

# energy production
joined %>%
  st_drop_geometry() %>%
  mutate(elcprd_ge700MW = ifelse(ElcPrd_MWh >= 700, 1, 0)) %>%
  count(elcprd_ge700MW)

joined %>%
  st_drop_geometry() %>%
  mutate(elcprd_ge700MW = ifelse(ElcPrd_MWh >= 700, 1, 0)) %>%
  count(elcprd_ge700MW, in_cz)

joined %>%
  st_drop_geometry() %>%
  group_by(in_cz) %>%
  summarise(nbuildings = n(),
            avg_energy_MWh = mean(ElcPrd_MWh),
            med_energy_MWh = median(ElcPrd_MWh),
            total_energy_MWh = sum(ElcPrd_MWh, na.rm = T))

cz_elcprd <- joined %>%
  st_drop_geometry() %>%
  group_by(cz_num) %>%
  summarise(avg_suitability = mean(index, na.rm = T),
            avg_energy_MWh = mean(ElcPrd_MWh, na.rm = T),
            total_energy_MWh = sum(ElcPrd_MWh, na.rm = T)) %>%
  ungroup() %>%
  mutate(cz_num = replace_na(as.character(cz_num), "Not in a CZ"))


# ll97 covered buildings trends
joined %>% 
  st_drop_geometry() %>%
  count(f_ll97) %>%
  mutate(pct = n/sum(n))

joined %>% 
  st_drop_geometry() %>%
  count(f_ll97, in_cz) %>%
  mutate(pct = n/sum(n))

# exploring trends among index score flags

## ratio of max to min values for each index score (this collapses scores over 0/1)
joined %>%
  st_drop_geometry() %>%
  select(starts_with("f_")) %>%
  summarise(across(starts_with("f_"), ~mean(.x, na.rm = T)/max(.x, na.rm = T)))

## PLOT showing frequency for all buildings and for buildings with higher index scores
# and hotspot buildings

f_freq_all <- joined %>%
  st_drop_geometry() %>%
  select(starts_with("f_")) %>%
  summarise(across(starts_with("f_"), ~mean(.x, na.rm = T)/max(.x, na.rm = T)), n = n()) %>%
  pivot_longer(cols = starts_with("f_")) %>%
  mutate(cz_num = "All")

f_freq_cz <- joined %>%
  st_drop_geometry() %>%
  group_by(cz_num = as.character(cz_num)) %>%
  select(starts_with("f_")) %>%
  summarise(across(starts_with("f_"), ~mean(.x, na.rm = T)/max(.x, na.rm = T)), n = n()) %>%
  pivot_longer(cols = starts_with("f_")) %>%
  mutate(cz_num = replace_na(cz_num, "Not in a CZ"))

f_freq <- bind_rows(f_freq_cz, f_freq_all) %>%
  mutate(name_long = case_when(
    name == "f_ll97" ~ "LL97 covered building",
    name == "f_lowroof" ~ "Low roof building",
    name == "f_mzone" ~ "In IBZ/low-rise manufacturing zone",
    name == "f_solrad" ~ "High solar radiation pootential",
    name == "f_lowres" ~ "Low-rise residential zone",
    name == "f_mulbldg" ~ "Owner owns other nearby buildings",
    name == "f_hd" ~ "In historic district",
    name == "f_disad" ~ "In federal disadvantaged community",
    name == "f_nys_dac" ~ "In state disadvantaged community"
  )) 

f_freq %>%
  ggplot(aes(y = name_long, x = value, fill = name_long)) + 
  geom_col(position = 'dodge') +
  facet_wrap(vars(cz_num)) + 
  labs(
    title = "Frequency of flag variables in each campaign zone",
    y = NULL,
    x = "Percent of buildings flagged for each variable"
  ) +
  # scale_fill_brewer(type = "qual") +
  theme_minimal() + 
  theme(legend.position = "none")
  
ggsave("dat/figures/nyc/flag comparison campaign zones.png", width = 13, height = 8, units = "in")


# 4. Give campaign zones a descriptive name -----------------------------------

#map of campaign zones with number in hover box to help set this up
hotspots %>%
  filter(fid == 22) %>%
tm_shape() + 
  tm_borders() + 
  tm_fill("fid") 

# "1" ~ "Eastchester",
# "2" ~ "Bay Plaza - Co-op City",
# "3" ~ "Inwood",
# "4" ~ "Claremont Park East",
# "5" ~ "Crotona Park East",
# "6" ~ "Highbridge - Macombs Dam",
# "7" ~ "Soundview",
# "8" ~ "Westchester Creek",
# "9" ~ "Mott Haven",
# "10" ~ "Harlem",
# "11" ~ "Port Morris - Hunts Point",
# "12" ~ "Rikers Island",
# "13" ~ "College Point",
# "14" ~ "Colleg Point - Whitestone",
# "15" ~ "College Point South",
# "16" ~ "Astoria",
# "17" ~ "East Elmhurst",
# "18" ~ "Flushing",
# "19" ~ "Ridgewood",
# "20" ~ "Jamaica/St. Albans",
# "21" ~ "Navy Yard - North Brooklyn IBZ - Sunnywide",
# "23" ~ "Red Hook - Governor's Island",
# "24" ~ "Ocean Hill - Brownsville",
# "25" ~ "JFK 1",
# "26" ~ "JFK 2",
# "27" ~ "JFK 3",
# "28" ~ "East New York - Flatlands IBZ",
# "29" ~ "Canarsie - Flatlands IBZ",
# "30" ~ "JFK 4",
# "31" ~ "Gowanus - Sunset Park",
# "32" ~ "Port Richmond - West Brighton",
# "33" ~ "Mariners Harbor - Portside",
# "34" ~ "Bath Beach",
# "35" ~ "Gravesend",

# create a summary stat table for reviewing campaign zones



cz_sum <- f_freq %>%
  pivot_wider(id_cols = c(cz_num, n),
              names_from = name_long, 
              values_from = value) %>%
  full_join(cz_elcprd, by = "cz_num") %>%
  mutate(campzone = case_when(
    cz_num == "1" ~ "Eastchester",
    cz_num == "2" ~ "Bay Plaza - Co-op City",
    cz_num == "3" ~ "Inwood",
    cz_num == "4" ~ "Claremont Park East",
    cz_num == "5" ~ "Crotona Park East",
    cz_num == "6" ~ "Highbridge - Macombs Dam",
    cz_num == "7" ~ "Soundview",
    cz_num == "8" ~ "Westchester Creek",
    cz_num == "9" ~ "Mott Haven",
    cz_num == "10" ~ "Harlem",
    cz_num == "11" ~ "Port Morris - Hunts Point",
    cz_num == "12" ~ "Rikers Island",
    cz_num == "13" ~ "College Point",
    cz_num == "14" ~ "Colleg Point - Whitestone",
    cz_num == "15" ~ "College Point South",
    cz_num == "16" ~ "Astoria",
    cz_num == "17" ~ "East Elmhurst",
    cz_num == "18" ~ "Flushing",
    cz_num == "19" ~ "Ridgewood",
    cz_num == "20" ~ "Jamaica/St. Albans",
    cz_num == "21" ~ "Navy Yard - North Brooklyn IBZ - Sunnywide",
    cz_num == "23" ~ "Red Hook - Governor's Island",
    cz_num == "24" ~ "Ocean Hill - Brownsville",
    cz_num == "25" ~ "JFK 1",
    cz_num == "26" ~ "JFK 2",
    cz_num == "27" ~ "JFK 3",
    cz_num == "28" ~ "East New York - Flatlands IBZ",
    cz_num == "29" ~ "Canarsie - Flatlands IBZ",
    cz_num == "30" ~ "JFK 4",
    cz_num == "31" ~ "Gowanus - Sunset Park",
    cz_num == "32" ~ "Port Richmond - West Brighton",
    cz_num == "33" ~ "Mariners Harbor - Portside",
    cz_num == "34" ~ "Bath Beach",
    cz_num == "35" ~ "Gravesend",
    TRUE           ~ cz_num
  )) %>%
  select(cz_num, campzone, everything())


joined %>%
  st_drop_geometry() %>%
  count(index, in_cz) %>%
  write_clip()

joined %>%
  st_drop_geometry() %>%
  count(f_solrad)

joined %>%
  st_drop_geometry() %>%
  group_by(in_cz) %>%
  summarise(n = n(),
            sum = sum())

joined %>%
  filter(cz_num == 5) %>%
  st_drop_geometry() %>%
  count(f_solrad) %>%
  mutate(pct = n/sum(n)) %>%
  adorn_totals()


# 5. Add descriptive variables to the file ------------------------------------

# RETI is interested in having the following information available for each
#  building:
# - IBZ name
# - BID name
# - CD number
# - City Council District

## Prep variables for being joined ----

### IBZ
ibz_short <- ibz %>%
  select(ibzname = NAME,
         geometry)

### BID
bid_short <- bid %>%
  filter(f_all_bi_1 == "Brooklyn") %>% #restrict to just Brooklyn
  select(bidname = f_all_bi_2,
         geometry) %>%
  st_transform(st_crs(joined))

### CD
cd_short <- cd %>%
  select(commdist = boro_cd,
         geometry) %>%
  st_transform(st_crs(joined))

### Council
cc_short <- council %>%
  select(coun_dist, geometry) %>%
  st_transform(st_crs(joined))

joined2 <- joined %>%
  st_join(ibz_short, join = st_intersects) %>%
  st_join(bid_short, join = st_intersects) %>%
  st_join(cd_short,  join = st_intersects) %>%
  st_join(cc_short,  join = st_intersects) %>%
  # cz_num is not descriptive, give campaign zones descriptive names
  mutate(row_num = row_number(), #create row-number for URL purposes
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
           cz_num == 35 ~ "Gravesend",
  ))

# # check that names and numbers properly reflect the neighborhood/zones covered
# tm_shape(joined2) +
#   tm_fill("campzone")

## Check joins
joined2 %>% st_drop_geometry() %>%
  count(f_mzone, ibzname)
# all IBZname values should be flagged as 1 in the manufacturing zone flag
#  but not all mzone flags will be within an IBZ

joined2 %>% st_drop_geometry() %>%
  count(bidname, commdist) %>%
  print(n = 100)
# sanity check: are BIDs mostly contained within 1-2 community districts?
#  and do the CDs align with the BID names?

joined2 %>% st_drop_geometry() %>%
  count(campzone, cz_num) %>%
  print(n = 100)


# 6. Save final files --------------------------------------------------------

# shorten variable names
joined3 <- joined2 %>%
  rename(resfarrat = ratio_residfar,
         off_name = officer_name,
         off_add = officer_add,
         man_name = manager_name,
         r_bdg = residential,
         r_bdgtype = r_bldgtype,
         roof_ht = heightroof,
         agnt_name = agent_name,
         ElcPrdMwh = ElcPrd_MWh)

# check variable name length
names(joined3) %>%
  as.data.frame() %>%
  mutate(nchar = nchar(.)) %>%
  arrange(desc(nchar))

# Shapefile for mapping
st_write(joined3, "dat/suitability index/nyc_analysis.shp", delete_dsn = T)

# Excel file to be shared with site staff
joined2 %>% 
  st_drop_geometry() %>%
  arrange(desc(in_cz), campzone, desc(index), bbl) %>%
  select(address, bin, bbl, suitability_score = index, near_reti_site = near_reti, campzone, 
         cz_num, zipcode, council_dist = coun_dist, commdist, ibzname, bidname,
         electricity_prodMWh = ElcPrd_MWh, tract2020 = bct2020, ownername, 
         starts_with("f_"),
         everything()) %>%
  write.xlsx("site analysis_nyc.xlsx")

# Excel file with campaign zone summary stats for me
write_csv(cz_sum, "nyc cz summary statistics.csv")



