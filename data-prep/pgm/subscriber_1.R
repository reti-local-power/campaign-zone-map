### Subscriber Analysis 
### 1. Subscriber File Collection

# The PURPOSE of this .R script is to pull the necessary datasets to describe
# potential solar subscriber bases within Brooklyn. This will be helpful as
# RETI Center determines primary site clusters for outreach and nearby subscriber
# bases among low-income renters

# After conversation with RETI Center & NYC 2030 District, they are looking for
# a much simpler subscriber map that can be incorporated alongside the site
# information. This script will simply combine the state and federal 
# disadvantaged community mapes to create one shapefile with 3 categories:
#  - in Federal DAC
#  - in State DAC
#  - in both DAC maps

# 0. Packages ------

library(tidyverse)
library(tidycensus)
library(janitor)
# library(clipr)
library(sf)

# 1. Read in data ----------

# + Census Tract cross-walk (2010 and 2020 geoid information)
## source: https://www.census.gov/geographies/reference-files/time-series/geo/relationship-files.2020.html
ct_cw <- read_delim("https://www2.census.gov/geo/docs/maps-data/data/rel2020/tract/tab20_tract20_tract10_st36.txt", 
                    delim = "|") %>%
  clean_names() %>%
  select(starts_with("geoid_tract")) %>%
  mutate(across(starts_with("geoid_tract"), as.character))


# + CEJST

# note that this uses 2010 census tract id which may not map perfectly and will
## require a cross-walk to 2020 census tract geographies

cejst <- read_csv("https://static-data-screeningtool.geoplatform.gov/data-versions/1.0/data/score/downloadable/1.0-communities.csv") %>%
  clean_names() %>%
  filter(state_territory == "New York" & county_name == "Kings County") %>%
  select(geoid_tract_10 = census_tract_2010_id, disadvantaged = identified_as_disadvantaged)


# + NYSERDA Disadvantaged communities

# restrict the API call to streamline data collected
nyserdaurl <- URLencode("https://data.ny.gov/resource/2e6c-s6fp.csv?$query=
                        SELECT the_geom, geoid, dac_designation, county
                        WHERE county = 'Kings' 
                        LIMIT 1000000")

nyserda <- read_csv(nyserdaurl) 

## Commented out - useful to see the full list of variables and standard string format
# nyserda_test <- read_csv("https://data.ny.gov/resource/2e6c-s6fp.csv")


# + Census data

## given the simplified format of this, we only need census geometries to move forward
acs <- get_acs("tract",
               variables = c(n_units = "S2503_C01_001"), #arbitrary and will be dropped later in this line of code
               year = 2022,
               state = "New York",
               county = "Kings",
               geometry = TRUE) %>%
  clean_names() %>% 
  select(geoid_tract_20 = geoid, name, geometry) #rename to be explicit about which geometries


# 2. Manipulate individual data to prepare for joining ------------------------

## CEJST ----
# needs to be linked to the census crosswalk so it is aligned with 2020 census
## tract information

cejst2 <- cejst %>%
  left_join(ct_cw, by = "geoid_tract_10") %>% #join to cross-walk
# note that this adds more rows, because many census tracts were subdivided
## and rearranged between the 2010 and 2020 census
# add flag for these census tracts and move on
  group_by(geoid_tract_10) %>%
  mutate(ct_change = ifelse(max(n()) > 1, 1, 0)) %>%
  ungroup() %>%
  mutate(in_cejst = 1)

# how many cases flagged in the census tract change flag? (111)
cejst2 %>% count(ct_change)

# does that count match the number of dupes? (Yes!)
get_dupes(cejst2, geoid_tract_10) %>% count(ct_change)

# now remove duplicates of the 2020 tract id's
cejst3 <- cejst2 %>%
  distinct(geoid_tract_20, disadvantaged, .keep_all = T) %>%
  #remove one remaining duplicate that shouldn't be kept
  filter(!(geoid_tract_20 == "36047048500" & geoid_tract_10 == "36047044900")) %>%
  mutate(cejst_dac = as.numeric(disadvantaged))

# confirm no duplicate geoids remain
get_dupes(cejst3, geoid_tract_20)


## NYSERDA ----

nyserda2 <- nyserda %>%
  mutate(geoid_tract_10 = as.character(geoid)) %>%
  left_join(ct_cw, by = "geoid_tract_10") %>% #join to cross-walk
  # note that this adds more rows, because many census tracts were subdivided
  ## and rearranged between the 2010 and 2020 census
  # add flag for these census tracts and move on
  group_by(geoid_tract_10) %>%
  mutate(ny_ct_change = ifelse(max(n()) > 1, 1, 0)) %>%
  ungroup() %>%
  mutate(in_nyserda = 1)

# how many cases flagged in the census tract change flag? (111)
nyserda2 %>% count(ny_ct_change)

# get_dupes(nyserda2, geoid_tract_20)

# does that count match the number of dupes? (Yes!)
get_dupes(nyserda2, geoid_tract_10) %>% count(ny_ct_change)

# now remove duplicates of the 2020 tract id's
nyserda3 <- nyserda2 %>%
  distinct(geoid_tract_20, dac_designation, .keep_all = T) %>%
  #remove one remaining duplicate that shouldn't be kept
  filter(!(geoid_tract_20 == "36047005100" & geoid_tract_10 == "36047005900")) %>%
  mutate(nyserda_dac = ifelse(dac_designation == "Designated as DAC", 1, 0)) %>%
  select(geoid_tract_20, nyserda_dac, ny_ct_change, in_nyserda)

# # check join (commented out because dac_designation is now removed from the 
# #  file but can be added back in to the above select function to re-run this check)
# nyserda3 %>% count(nyserda_dac, dac_designation)

# confirm no remaining duplicates of geoid_tract_20
get_dupes(nyserda3, geoid_tract_20)


# 3. Join datasets together ---------------------------------------------------

acs_nyserda <- acs %>%
  left_join(nyserda3, by = "geoid_tract_20") 

# check that lead data is available for all tracts
acs_nyserda %>% st_drop_geometry() %>% count(in_nyserda)

joined <- acs_nyserda %>%
  left_join(cejst3, by = "geoid_tract_20") %>%
  mutate(dac_cat = case_when(
    nyserda_dac == 1 & cejst_dac == 1 ~ "Both DAC",
    nyserda_dac == 1 & cejst_dac == 0 ~ "NYSERDA DAC",
    nyserda_dac == 0 & cejst_dac == 1 ~ "CEJST DAC",
    nyserda_dac == 0 & cejst_dac == 0 ~ "None"
  )) %>%
  relocate(geometry, .after = last_col())

# check that cejst data is available for all tracts
joined %>% st_drop_geometry() %>% count(in_cejst)

# check new combined DAC variable creation
joined %>% st_drop_geometry() %>% count(dac_cat, nyserda_dac, cejst_dac)

# check how many NA values for each variable (none!)
sapply(joined, function(x) sum(is.na(x)))


# 4. Create interactive map ---------------------------------------------------

# blank for now, haven't figure out how to do this yet

# 5. Export joined data -------------------------------------------------------

names(joined) %>%
  as.data.frame() %>%
  mutate(nchar = nchar(.)) %>%
  arrange(desc(nchar))

# shorten names to avoid everything being shortened while exporting
joined2 <- joined %>%
  select(geoid = geoid_tract_20, name, dac_cat, geometry)

st_write(joined2, "dat/subscriber areas/subscriber_attributes.shp", delete_dsn = TRUE)

