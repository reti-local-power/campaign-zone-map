### Subscriber Analysis 
### 1. Subscriber File Collection

# The PURPOSE of this .R script is to pull the necessary datasets to describe
# potential solar subscriber bases within Brooklyn (and NYC). This will be helpful as
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

cejst_nyc <- read_csv("https://static-data-screeningtool.geoplatform.gov/data-versions/1.0/data/score/downloadable/1.0-communities.csv") %>%
  clean_names() %>%
  filter(state_territory == "New York" & 
           county_name %in% c("Bronx County", "Kings County", "New York County", "Queens County", "Richmond County")) %>%
  select(geoid_tract_10 = census_tract_2010_id, disadvantaged = identified_as_disadvantaged)


# + NYSERDA Disadvantaged communities

# restrict the API call to streamline data collected
nyserdaurl <- URLencode("https://data.ny.gov/resource/2e6c-s6fp.csv?$query=
                        SELECT the_geom, geoid, dac_designation, county
                        WHERE county = 'Kings' 
                        LIMIT 1000000")

nyserda <- read_csv(nyserdaurl) 


nyserdaurl_nyc <- URLencode("https://data.ny.gov/resource/2e6c-s6fp.csv?$query=
                        SELECT the_geom, geoid, dac_designation, county
                        WHERE county IN('Bronx', 'New York', 'Kings', 'Queens', 'Richmond')
                        LIMIT 1000000")

nyserda_nyc <- read_csv(nyserdaurl_nyc) 

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

acs_nyc <- get_acs("tract",
               variables = c(n_units = "S2503_C01_001"), #arbitrary and will be dropped later in this line of code
               year = 2022,
               state = "New York",
               county = c("Bronx", "New York", "Kings", "Queens", "Richmond"),
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

### Repeat for NYC-wide version ----
cejst2_nyc <- cejst_nyc %>%
  left_join(ct_cw, by = "geoid_tract_10") %>% #join to cross-walk
  # note that this adds more rows, because many census tracts were subdivided
  ## and rearranged between the 2010 and 2020 census
  # add flag for these census tracts and move on
  group_by(geoid_tract_10) %>%
  mutate(ct_change = ifelse(max(n()) > 1, 1, 0)) %>%
  ungroup() %>%
  mutate(in_cejst = 1)

# how many cases flagged in the census tract change flag? (111)
cejst2_nyc %>% count(ct_change)

# does that count match the number of dupes? (Yes!)
get_dupes(cejst2_nyc, geoid_tract_10) %>% count(ct_change)

# now remove duplicates of the 2020 tract id's
cejst3_nyc <- cejst2_nyc %>%
  distinct(geoid_tract_20, disadvantaged, .keep_all = T) %>%
  #remove one remaining duplicate that shouldn't be kept
  filter(!(geoid_tract_20 == "36047048500" & geoid_tract_10 == "36047044900")) %>%
  #flag remaining duplicates
  group_by(geoid_tract_20) %>%
  mutate(dupflag = ifelse(n() > 1, 1, 0),
         dropflag = ifelse(dupflag == 1 & geoid_tract_20 != geoid_tract_10, 1, 0),
         dropflag2 = case_when(
           dupflag == 1 & min(dropflag) == 0 & dropflag == 1 ~ 1, #drop dupes that are the only one caught by dropflag
           dupflag == 1 & min(dropflag) == 1 & row_number() == 2 ~ 1, #drop an arbitrary dupe if both have the same dac value,
           TRUE ~ 0
         )) %>%
  ungroup() %>%
  mutate(cejst_dac = as.numeric(disadvantaged))

# some duplicates remain, confirm that all of them are caught by the new dupflag
get_dupes(cejst3_nyc, geoid_tract_20) %>% print(n = 100)

cejst3_nyc %>% count(dupflag, dropflag)
# they are!
cejst3_nyc %>% count(dupflag, dropflag2)
# and dropflag2 captures exactly half of them (which is what we want)

#this step removes duplicates where
# - the 2010 geoid does not match the 2020 geoid (and the other record does)
# - both duplicates have the same disadvantaged flag (so it doesn't matter)

# in these cases, keep the row where the 2010 tract matches the 2020 tract
cejst4_nyc <- cejst3_nyc %>%
  filter(dropflag2 == 0) %>%
  select(-dupflag, dropflag, dropflag2)


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

### Repeat for NYC-wide version ----

nyserda2_nyc <- nyserda_nyc %>%
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
nyserda2_nyc %>% count(ny_ct_change)

# get_dupes(nyserda2_nyc, geoid_tract_20)

# does that count match the number of dupes? (Yes!)
get_dupes(nyserda2_nyc, geoid_tract_10) %>% count(ny_ct_change)

# now remove duplicates of the 2020 tract id's
nyserda3_nyc <- nyserda2_nyc %>%
  distinct(geoid_tract_20, dac_designation, .keep_all = T) %>%
  #remove one remaining duplicate that shouldn't be kept
  filter(!(geoid_tract_20 == "36047005100" & geoid_tract_10 == "36047005900")) %>%
  #flag remaining duplicates
  group_by(geoid_tract_20) %>%
  mutate(dupflag = ifelse(n() > 1, 1, 0),
         dropflag = ifelse(dupflag == 1 & geoid_tract_20 != geoid_tract_10, 1, 0),
         dropflag2 = case_when(
           dupflag == 1 & min(dropflag) == 0 & dropflag == 1 ~ 1, #drop dupes that are the only one caught by dropflag
           dupflag == 1 & min(dropflag) == 1 & row_number() == 2 ~ 1, #drop an arbitrary dupe if both have the same dac value,
           TRUE ~ 0
         )) %>%
  ungroup() %>%
  mutate(nyserda_dac = ifelse(dac_designation == "Designated as DAC", 1, 0)) 

# # check join (commented out because dac_designation is now removed from the 
# #  file but can be added back in to the above select function to re-run this check)
# nyserda3 %>% count(nyserda_dac, dac_designation)

# confirm no remaining duplicates of geoid_tract_20
get_dupes(nyserda3_nyc, geoid_tract_20) %>% print(n = 100)

# dropflag2 should be exactly half of dupflag
nyserda3_nyc %>%
  st_drop_geometry() %>% 
  count(dupflag, dropflag2)

nyserda4_nyc <- nyserda3_nyc %>%
  filter(dropflag2 == 0) %>%
  select(geoid_tract_20, nyserda_dac, ny_ct_change, in_nyserda)


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

## Repeat for NYC ----

acs_nyserda_nyc <- acs_nyc %>%
  left_join(nyserda4_nyc, by = "geoid_tract_20") 

# check that lead data is available for all tracts
acs_nyserda_nyc %>% st_drop_geometry() %>% count(in_nyserda)

joined_nyc <- acs_nyserda_nyc %>%
  left_join(cejst4_nyc, by = "geoid_tract_20") %>%
  mutate(dac_cat = case_when(
    nyserda_dac == 1 & cejst_dac == 1 ~ "Both DAC",
    nyserda_dac == 1 & cejst_dac == 0 ~ "NYSERDA DAC",
    nyserda_dac == 0 & cejst_dac == 1 ~ "CEJST DAC",
    nyserda_dac == 0 & cejst_dac == 0 ~ "None"
  )) %>%
  relocate(geometry, .after = last_col())

# check that cejst data is available for all tracts
joined_nyc %>% st_drop_geometry() %>% count(in_cejst)

# check new combined DAC variable creation
joined_nyc %>% st_drop_geometry() %>% count(dac_cat, nyserda_dac, cejst_dac)

# check how many NA values for each variable (none!)
sapply(joined_nyc, function(x) sum(is.na(x)))


# 4. Export joined data -------------------------------------------------------

names(joined) %>%
  as.data.frame() %>%
  mutate(nchar = nchar(.)) %>%
  arrange(desc(nchar))

# shorten names to avoid everything being shortened while exporting
joined2 <- joined %>%
  select(geoid = geoid_tract_20, name, dac_cat, geometry)

## Do same for NYC-wide ----
names(joined_nyc) %>%
  as.data.frame() %>%
  mutate(nchar = nchar(.)) %>%
  arrange(desc(nchar))

# shorten names to avoid everything being shortened while exporting
joined2_nyc <- joined_nyc %>%
  select(geoid = geoid_tract_20, name, dac_cat, geometry)


st_write(joined2_nyc, "dat/subscriber areas/subscriber_attributes_nyc.shp", delete_dsn = TRUE)

