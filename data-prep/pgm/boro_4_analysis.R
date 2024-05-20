### Demonstration Analysis

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


# 1. Read in data -------------------------------------------------------------

# - index score csv
bf <- read_csv("dat/boro_bldg_fp_index_and_elecprod.csv") %>%
  #remove duplicate variable
  select(-elcprd_MWh)


# - index score shapefile with hotspot
bf_shp <- st_read("dat/suitability index/boro_suitability_index_hotspot.shp")


# - BID (helpful for final spreadsheet)
bid <- st_read("https://data.cityofnewyork.us/resource/7jdm-inj8.geojson")

# - IBZ (helpful for final spreadsheet)
ibz_temp <- tempfile()
ibz_temp2 <- tempfile()

download.file("https://edc.nyc/sites/default/files/2020-10/IBZ%20Shapefiles.zip", ibz_temp)

unzip(ibz_temp, exdir = ibz_temp2)

ibz <- st_read(ibz_temp2)

# - Community Districts (helpful for final spreadsheet)
cd <- st_read("https://data.cityofnewyork.us/resource/jp9i-3b7y.geojson") %>%
  filter(str_sub(boro_cd, 1, 1) == "3") #restrict to just Brooklyn CDs

# - City Council Districts (helpful for final spreadsheet)
council <- st_read("https://data.cityofnewyork.us/resource/s2hu-y8ab.geojson") %>%
  #filter to Brooklyn Council Districts
  filter(as.numeric(coun_dist) > 33 &
           as.numeric(coun_dist) < 49)


# 2. Join data together -------------------------------------------------------

# identify duplicated variables to remove before joining
compare_df_cols(bf, bf_shp) %>% 
  as.data.frame() %>% 
  filter(!is.na(bf) & !is.na(bf_shp) & column_name != "bin") %>%
  pull(column_name)

# clean up the hotspot outputted variables to keep only the relevant ones
bf_shp2 <- bf_shp %>%
  select(bin, cz_num, in_cz)

joined <- bf %>%
  mutate(bin = as.character(bin)) %>%
  left_join(bf_shp2, by = "bin") %>%
  mutate(ratio_residfar = ifelse(is.infinite(ratio_residfar), NA, ratio_residfar)) %>%
  st_as_sf()


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
  
ggsave("dat/figures/boro/flag comparison campaign zones.png", width = 13, height = 8, units = "in")


# create a summary stat table for reviewing campaign zones
cz_sum <- f_freq %>%
  pivot_wider(id_cols = c(cz_num, n),
              names_from = name_long, 
              values_from = value) %>%
  full_join(cz_elcprd, by = "cz_num") %>%
  mutate(campzone = case_when(
    cz_num == "1"  ~ "Greenpoint IBZ",
    cz_num == "2"  ~ "North Brooklyn Waterfront",
    cz_num == "3"  ~ "Downtown BK/Naby Yard/North Brooklyn IBZ",
    cz_num == "4"  ~ "Red Hook/Gowanus",
    cz_num == "5"  ~ "East New York IBZ",
    cz_num == "6"  ~ "East New York - Flatlands IBZ",
    cz_num == "7"  ~ "Canarsie - Flatlands IBZ",
    cz_num == "8"  ~ "Starrett City",
    cz_num == "9"  ~ "Prospect Park South",
    cz_num == "10" ~ "Sunset Park",
    cz_num == "11" ~ "Sheepshead Bay - Nostrand Houses",
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


# 4. Add descriptive variables to the file ------------------------------------

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
           cz_num == 1  ~ "Greenpoint IBZ",
           cz_num == 2  ~ "North Brooklyn Waterfront",
           cz_num == 3  ~ "Downtown BK/Naby Yard/North Brooklyn IBZ",
           cz_num == 4  ~ "Red Hook/Gowanus",
           cz_num == 5  ~ "East New York IBZ",
           cz_num == 6  ~ "East New York - Flatlands IBZ",
           cz_num == 7  ~ "Canarsie - Flatlands IBZ",
           cz_num == 8  ~ "Starrett City",
           cz_num == 9 ~ "Prospect Park South",
           cz_num == 10  ~ "Sunset Park",
           cz_num == 11 ~ "Sheepshead Bay - Nostrand Houses",
  ))

# check that names and numbers properly reflect the neighborhood/zones covered
tm_shape(joined2) + 
  tm_fill("campzone")

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
  count(cz_top, campzone, cz_num)

joined2 %>% 
  st_drop_geometry() %>%
  filter(cz_num == 5) %>%
  count(commdist) %>%
  mutate(pct = n/sum(n)) %>%
  adorn_totals()


# 5. Save final files --------------------------------------------------------

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
st_write(joined3, "dat/suitability index/boro_analysis.shp", delete_dsn = T)

# Excel file to be shared with site staff
joined2 %>% 
  st_drop_geometry() %>%
  arrange(desc(in_cz), campzone, desc(index), bbl) %>%
  select(address, bin, bbl, suitability_score = index, campzone, 
         cz_num, zipcode, council_dist = coun_dist, commdist, ibzname, bidname,
         electricity_prodMWh = ElcPrd_MWh, tract2020 = bct2020, ownername, 
         starts_with("f_"),
         everything()) %>%
  write.xlsx("site analysis_brooklyn.xlsx")

# Excel file with campaign zone summary stats for me
write_csv(cz_sum, "cz summary statistics.csv")



