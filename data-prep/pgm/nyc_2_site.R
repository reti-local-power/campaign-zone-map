### City-wide Analysis

### 2. Site Suitability

# The PURPOSE of this .R script is to identify potential solar sites and clusters
# within the study area (NYC) using the cleaned file from
# the previous script
# 
# The screening happens in two steps:
#   - First a 'fatal flaw' analysis for buildings that have rooftop solar & 
#     low solar radiation potential
#   - Second, a scoring system to develop a 'suitability index' based on land
#     use, ownership status, and sustainability policy factors. Through consultation
#     with RETI and NYC 2030, buildings were be removed based on a score threshold


# 0. Packages -----------------------------------------------------------------

library(units)
library(tidyverse)
library(openxlsx)
library(janitor)
library(clipr)
library(sf)
library(tmap)

tmap_mode("view")
tmap_options(check.and.fix = TRUE)


# 1. Read in data -------------------------------------------------------------

# + Building footprint 
# note: the file is restricted to buildings with area of 8,000+ sf in nyc_1_raw
#       to keep the file size smaller (this shapefile is very large)
bf <- st_read("dat/bldg fp bk/nyc_bf.shp") %>%
  distinct(bin, .keep_all = T)

# + NYSERDA community solar projects
# note: per the data dictionary, lat/lon and address info is only available for
#       non-residential projects. residential records are dropped to preserve
#       value of the geospatial information
nyserdaurl <- URLencode("https://data.ny.gov/resource/3x8r-34rs.csv?$query=SELECT * 
                        WHERE electric_utility = 'Consolidated Edison' AND 
                        county IN('Bronx', 'Kings', 'New York', 'Queens', 'Richmond') AND 
                        street_address IS NOT NULL
                        LIMIT 1000000")

nyserda <- read_csv(nyserdaurl)


# + PLUTO (read in from online zip source)
pluto_temp <- tempfile()

download.file("https://s-media.nyc.gov/agencies/dcp/assets/files/zip/data-tools/bytes/nyc_pluto_24v1_csv.zip", 
              pluto_temp)

unzip(pluto_temp)

pluto <- read_csv("pluto_24v1.csv",
                  col_types = cols(ct2010 = "c", cb2010 = "c")) 


# + Solar Radiation Data 
nyc_solrad <- read_csv("dat/Solar Power Potential/nyc_bldg_fp_elcprd.csv",
                       col_types = list(bin = col_character())) %>%
  arrange(desc(ElcPrd_MWh)) %>%
  distinct(bin, .keep_all = T)

# + IBZ
ibz_temp <- tempfile()
ibz_temp2 <- tempfile()

download.file("https://edc.nyc/sites/default/files/2020-10/IBZ%20Shapefiles.zip", ibz_temp)

unzip(ibz_temp, exdir = ibz_temp2)

ibz <- st_read(ibz_temp2)


# + CEJST
cejst <- read_csv("https://static-data-screeningtool.geoplatform.gov/data-versions/1.0/data/score/downloadable/1.0-communities.csv") %>%
  clean_names() %>%
  filter(state_territory == "New York" & 
           county_name %in% c("Bronx County", "Kings County", "New York County", "Queens County", "Richmond County")) %>%
  select(tract_id = census_tract_2010_id, disadvantaged = identified_as_disadvantaged)


# + NYSERDA Disadvantaged communities

# restrict the API call to streamline data collected
nyserda_dac_url <- URLencode("https://data.ny.gov/resource/2e6c-s6fp.csv?$query=
                        SELECT the_geom, geoid, dac_designation, county
                        WHERE county IN('Bronx', 'Kings', 'New York', 'Queens', 'Richmond')
                        LIMIT 1000000")

nyserda_dac <- read_csv(nyserda_dac_url)


# + LL97 covered buildings
# source: https://www.nyc.gov/site/sustainablebuildings/requirements/covered-buildings.page
ll97 <- read.xlsx("https://www.nyc.gov/assets/buildings/excel/cbl_all.xlsx", 
                  startRow = 5) %>% #skip some header rows at the top
  clean_names() 


# + HPD Multiple Dwelling Registrations
# source:
hpd_regs_url <- URLencode("https://data.cityofnewyork.us/resource/tesw-yqqr.csv?$query=SELECT registrationid, bin
                           LIMIT 1000000")

hpd_regs <- read_csv(hpd_regs_url)

# + HPD Registration Contacts
# source: 
hpd_contacts <- read_csv("https://data.cityofnewyork.us/resource/feu5-w2e2.csv")

hpd_contacts_url <- URLencode("https://data.cityofnewyork.us/resource/feu5-w2e2.csv?$query=SELECT *
                               LIMIT 1000000")

hpd_contacts <- read_csv(hpd_contacts_url)


# + RETI site bldg footprint data
reti_projects <- st_read("dat/reti_projects/reti_solar_projects_bf.geojson")


# 2. Flag sufficiently large building footprints ------------------------------
## Note that this is duplicating a step done in the first script to save space

bf2 <- bf %>%
  # need to convert this to a numeric var, right now it's in units format to 
  #  preserve the units for documentation
  mutate(shape_area = as.numeric(shape_area),
         siteflag  = ifelse(shape_area > 8000, 1, 0))

bf2 %>% 
  st_drop_geometry() %>%
  count(siteflag) %>%
  mutate(pct = n/sum(n))
# there are 7,902 buildings with >8k sq ft building footprints. Lots to choose from!

bf2 %>%
  st_drop_geometry() %>%
  get_dupes(bin)
# bin is a unique identifier for each building, this may be helpful for identifying campuses


# 3. Fatal flaw screening -----------------------------------------------------

# There are two steps: catching NYSERDA-funded solar projects & 
#   solar radiation potential on rooftops

## Remove buildings that already have solar planned on them ----

nyserda_sf <- nyserda %>%
  mutate(addressfull = paste0(street_address, " ", city, ", NY")) %>%
  filter(!is.na(latitude) & !is.na(longitude)) %>% #only keep buildings with point info
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326) %>%
  select(nyserda_pn = project_number, project_status, street_address, is_commsolar = community_distributed_generation, geometry) %>%
  st_transform(st_crs(2263))

bf3 <- bf2 %>%
  st_join(nyserda_sf, st_intersects) %>%
  mutate(nyserda_solar = ifelse(!is.na(nyserda_pn), 1, 0))

# 980 NYSERDA funded sites are within the demonstration area
bf3 %>% 
  st_drop_geometry() %>% 
  mutate(is_nyserda = !is.na(nyserda_pn)) %>% 
  count(is_nyserda, is_commsolar) %>%
  mutate(pct = n/sum(n))

bf3 %>%
  st_drop_geometry() %>%
  filter(siteflag == 1) %>%
  mutate(is_nyserda = !is.na(nyserda_pn)) %>%
  count(is_nyserda) %>%
  mutate(pct = n/sum(n))

bf3_ck <- bf3 %>%
  mutate(bbl = as.double(mpluto_bbl)) %>%
  # check that nyserda geocoded point is within the address that it should be
  left_join(pluto, by = "bbl")

# check address mismatch in a sample of 100 buildings
bf3_ck %>%
  st_drop_geometry() %>%
  filter(!is.na(nyserda_pn)) %>%
  mutate(street_address = toupper(street_address)) %>%
  select(street_address, address) %>%
  head(100)


## Zero solar radiation ----
bf4 <- bf3 %>%
  left_join(nyc_solrad %>% 
              st_drop_geometry() %>% 
              select(bin) %>%
              mutate(anysolar = 1),
            by = "bin")

bf4 %>%
  st_drop_geometry() %>%
  count(anysolar)


## Final checks & remove flawed sites ----

# How many buildings are dropped by each criteria?

bf_noflaw <- bf4 %>%
  filter(siteflag == 1) %>%      # drop small buildings
  filter(is.na(nyserda_pn)) %>%  # drop buildings with nyserda projects
  filter(anysolar == 1)          # drop buildings without any solar radiation

# in this step, screen out buildings based on the fatal flaw flags

# confirm no nyserda projects & all have solar potential in the filtered data
bf_noflaw %>% 
  st_drop_geometry() %>%
  count(nyserda_solar, anysolar)


# 4. Suitability index creation -----------------------------------------------

# create suitability index for remaining buildings

# Flags include:
#   - Building height is < 100 ft or < 30 ft (0/1/2)
#   - Presence in IBZ or zoned manufacturing M1/M2 (0/1)
#   - Soft site outside of manufacturing zone (0/1)
#   - In Historic District (0/1)
#   - Property owner owns another building in the dataset (0/1)
#   - Presence within IRA Disadvantaged Community Map (0/1)
#   - LL97 covered building (0/2) <-- RETI wants this to weight higher than other factors
#   - Solar radiation (0/1/2/3) <-- RETI wants this to be weighted the heaviest


## low building height ----
bf_noflaw2 <- bf_noflaw %>%
  mutate(heightroof = as.numeric(heightroof),
         f_lowroof = case_when(
           is.na(heightroof) ~ 0,
           heightroof < 30   ~ 2,
           heightroof < 100  ~ 1,
           TRUE              ~ 0)
         )

# check creation
bf_noflaw2 %>%
  st_drop_geometry() %>% 
  count(f_lowroof)

bf_noflaw2 %>%
  st_drop_geometry() %>%
  group_by(f_lowroof) %>%
  summarise(n = n(),
            min = min(heightroof, na.rm = T),
            max = max(heightroof, na.rm = T),
            mean = mean(heightroof, na.rm = T))

## ibz or zoned manufacturing ----
ibz_union <- ibz %>%
  st_union() %>%
  st_sf()

bf_noflaw3 <- bf_noflaw2 %>%
  mutate(bbl = as.double(mpluto_bbl)) %>% # create bbl var that can join with numeric version on PLUTO file
  left_join(pluto, by = "bbl") %>%
  mutate(in_ibz = as.numeric(st_intersects(., ibz_union, sparse = F)),
         in_manufacturing = ifelse(str_sub(zonedist1, 1, 2) %in% c("M1", "M2"), 1, 0),
         f_mzone = ifelse(in_ibz == 1 | in_manufacturing == 1, 1, 0))

bf_noflaw3 %>%
  st_drop_geometry() %>%
  count(in_ibz)

bf_noflaw3 %>%
  st_drop_geometry() %>%
  mutate(zonedistcategory = str_sub(zonedist1, 1, 2)) %>%
  count(in_manufacturing, zonedistcategory, zonedist1) %>%
  arrange(desc(in_manufacturing))

bf_noflaw3 %>%
  st_drop_geometry() %>%
  count(in_ibz, in_manufacturing, f_mzone)


## soft site outside of manufacturing ----
# currently the code doesn't incorporate FAR, but it can if that's relevant
#  for RETI & NYC 2030 district

zonelist <- c("R1", "R2", "R3", "R4", "R5", "R6")

bf_noflaw4 <- bf_noflaw3 %>%
  mutate(f_lowres = ifelse(str_sub(zonedist1, 1, 2) %in% zonelist, 1, 0),
         ratio_residfar = builtfar / residfar)

#check
bf_noflaw4 %>%
  st_drop_geometry() %>%
  group_by(f_lowres) %>%
  summarise(n = n(),
            min = min(ratio_residfar, na.rm = T),
            max = max(ratio_residfar, na.rm = T),
            med = median(ratio_residfar, na.rm = T),
            mean = mean(ratio_residfar, na.rm = T))

## landmark or historic district ----

bf_noflaw5 <- bf_noflaw4 %>%
  mutate(f_hd = ifelse(!is.na(histdist) & histdist != "Individual Landmark", 1, 0))

bf_noflaw5 %>% 
  st_drop_geometry() %>%
  count(f_hd, histdist)

## property owner owns another building ----

# flag text options without substantive information
make_na <- "<NA>|UNAVAILABLE OWNER|NAME NOT ON FILE"

## Check for names (commented out for now)
# bf_noflaw5 %>%
#   st_drop_geometry() %>%
#   mutate(ownername = str_replace(ownername, make_na, NA_character_)) %>%
#   count(ownername) %>%
#   filter(n > 1) %>%
#   arrange(desc(n))

bf_noflaw5 %>%
  st_drop_geometry() %>%
  get_dupes(mpluto_bbl) %>%
  select(mpluto_bbl) %>%
  distinct(mpluto_bbl)

bf_noflaw6 <- bf_noflaw5 %>%
  mutate(ownername = str_replace(ownername, make_na, NA_character_),
         ownername_zip = paste(ownername, zipcode, sep = ""),
         f_mulbldg = as.numeric(ownername_zip %in% ownername_zip[duplicated(ownername_zip)]),
         f_mulbldg = ifelse(is.na(ownername), 0, f_mulbldg)) %>% #make NA owner name
  group_by(mpluto_bbl) %>%
  mutate(n = row_number(),
         dupe = ifelse(max(n) > 1, 1, 0),
         f_mulbldg = ifelse(dupe ==  1, 2, f_mulbldg)) %>%
  ungroup()

# check that the flag is correctly identifying duplicates within a zip code (commented out because this check is long)
# bf_noflaw6 %>%
#   st_drop_geometry() %>%
#   mutate(ownername = str_replace(ownername, make_na, NA_character_)) %>%
#   count(ownername, f_mulbldg) %>%
#   arrange(desc(n), f_mulbldg) %>%
#   head(100)

bf_noflaw6 %>% 
  st_drop_geometry() %>% 
  filter(f_mulbldg >= 1) %>% 
  count(f_mulbldg, mpluto_bbl) %>% 
  count(n)

bf_noflaw6 %>%
  st_drop_geometry() %>%
  count(dupe, f_mulbldg)


## presence in CEJST disadvantaged census tract ----

#create full census tract and block group id's
bf_noflaw7 <- bf_noflaw6 %>%
  mutate(tract_suffix = case_when(
    str_detect(ct2010, "\\.") ~ str_pad(ct2010, 7, "left", "0"),
    TRUE                      ~ str_pad(paste0(ct2010, ".00"), 7, "left", "0")
  ),
  tract_id = case_when(
    borough == "BX" ~ paste0("36005", str_remove(tract_suffix, "\\.")),
    borough == "BK" ~ paste0("36047", str_remove(tract_suffix, "\\.")),
    borough == "MN" ~ paste0("36061", str_remove(tract_suffix, "\\.")),
    borough == "QN" ~ paste0("36081", str_remove(tract_suffix, "\\.")),
    borough == "SI" ~ paste0("36085", str_remove(tract_suffix, "\\.")),
    )) %>%
  left_join(cejst, by = "tract_id") %>%
  mutate(f_disad = as.numeric(disadvantaged)) #keep flags in numeric format

# check creation of new versions of the census tract var
## for random set
bf_noflaw7 %>% 
  st_drop_geometry() %>% 
  select(borough, ct2010, tract_suffix, tract_id) %>% 
  slice_sample(n = 10)

## for tracts with a decimal and suffix
bf_noflaw7 %>% 
  st_drop_geometry() %>% 
  filter(str_detect(ct2010, "\\.")) %>% 
  select(ct2010, tract_suffix, tract_id) %>% 
  slice_sample(n = 10)

# check merge (should be values for all 5 boroughs)
bf_noflaw7 %>% 
  st_drop_geometry() %>% 
  count(borough, disadvantaged, f_disad)

# # there are 11 rows without census tract information
# bf_noflaw7 %>% filter(is.na(disadvantaged)) %>% select(ct2010, tract_id)


## LL97 covered building ----
# note: this is a 0/2 variable because this factor is more important in the scale

#there are duplicates in the ll97 data, make sure to deduplicate
get_dupes(ll97, bbl)

ll97_deduped <- ll97 %>%
  distinct(bbl, .keep_all = T)

bf_noflaw8 <- bf_noflaw7 %>%
  left_join(ll97_deduped %>%
              transmute(bbl = bbl, "f_ll97" = 2),
            by = "bbl") %>%
  mutate(f_ll97 = replace_na(f_ll97, 0))

bf_noflaw8 %>% 
  st_drop_geometry() %>% 
  count(f_ll97)


## Solar radiation potential ----
# This is the most important weight, and has several point values

bf_noflaw9 <- bf_noflaw8 %>%
  left_join(nyc_solrad %>%
              st_drop_geometry() %>%
              select(bin, ElcPrd_MWh) %>%
              mutate(in_solrad = 1), 
            by = "bin") %>%
  mutate(f_solrad = case_when(
    ElcPrd_MWh < 100 ~ 0,
    ElcPrd_MWh < 350 ~ 1,
    ElcPrd_MWh < 700 ~ 2,
    ElcPrd_MWh < 1050 ~ 3,
    ElcPrd_MWh >= 1050 ~ 4
  ))


# look at merge
bf_noflaw9 %>%
  st_drop_geometry() %>%
  count(siteflag, nyserda_solar, in_solrad)

# check flag var creation
bf_noflaw9 %>%
  st_drop_geometry() %>%
  group_by(f_solrad) %>%
  summarise(n = n(),
            n_na = sum(is.na(ElcPrd_MWh)),
            min = min(ElcPrd_MWh, na.rm = T),
            avg = mean(ElcPrd_MWh, na.rm = T),
            med = median(ElcPrd_MWh, na.rm = T),
            max = max(ElcPrd_MWh, na.rm = T))


## presence in NYSERDA disadvantaged community ----

nyserda_dac2 <- nyserda_dac %>%
  mutate(tract_id = as.character(geoid))

#create full census tract and block group id's
bf_noflaw10 <- bf_noflaw9 %>%
  left_join(nyserda_dac2, by = "tract_id") %>%
  mutate(f_nys_dac = as.numeric(dac_designation == "Designated as DAC")) #keep flags in numeric format

# check merge
bf_noflaw10 %>% 
  st_drop_geometry() %>% 
  count(dac_designation, f_nys_dac)

# # there are 11 rows without census tract information
# bf_noflaw10 %>% filter(is.na(f_nys_dac)) %>% select(ct2010, tract_id)


## create clustering bonus points for larger buildings ----
#    these categories are larger to counteract the impact of the clustering 
#    algorithm in QGIS and are not included in the site suitability score

# look at trends in building footprint size
summary(bf_noflaw10$shape_area)

# ggplot(bf_noflaw10, aes(x=shape_area)) + 
#   geom_histogram(bins=100) + 
#   xlim(0,30000)

bf_noflaw11 <- bf_noflaw10 %>%
  mutate(area_cat = case_when(
    shape_area <= 10000 ~ 0,
    shape_area <= 15000 ~ 2,
    shape_area <= 25000 ~ 4,
    shape_area >  25000 ~ 6
  ))

# look at distribution, does it seem to capture a similar proportion of buildings?
bf_noflaw11 %>%
  st_drop_geometry() %>%
  count(area_cat) %>%
  mutate(pct = n/sum(n))


## sum of flags ----
bf_index <- bf_noflaw11 %>%
  select(bbl, bin, starts_with("f_"), area_cat, elcprd_MWh = ElcPrd_MWh) %>%
  rowwise() %>%
  mutate(index = sum(c_across(starts_with("f_")), na.rm = T),
         bbl = as.character(bbl))

bf_index %>% st_drop_geometry() %>% count(index)


#bar chart showing the frequency of different index scores
bf_index %>%
  st_drop_geometry() %>%
  ggplot(aes(x = index)) + 
  geom_bar() + 
  labs(
    title = "Spread of buildings by Suitability Index Score",
    subtitle = "All suitable Brooklyn buildings",
    x = "Suitability Index Score",
    y = "Number of buildings"
  ) + 
  scale_x_continuous(breaks = c(0, seq(1:14)),
                     minor_breaks = NULL) + 
  theme_minimal()


# 5. Create clustering score (incorporate proximity to NYCHA bbl) -------------
reti_buffer <- reti_projects %>%
  st_transform(st_crs(2263)) %>%
  st_buffer(5280)

reti_union <- st_union(reti_buffer) %>%
  st_sf() %>%
  #this will become the clustering score value, adjust as needed
  mutate(near_reti = 1) 

# view spatial manipulation
# tm_shape(reti_union) +
#   tm_fill("red") +
#   tm_shape(reti_buffer) +
#   tm_polygons("blue")

# create flag if bf_index site is within nycha_union
bf_cluster <- bf_index %>%
  st_join(reti_union) %>%
  rowwise() %>%
  mutate(near_reti = replace_na(near_reti, 0),
         near_reti2 = near_reti * 2, #create 2-point flag to check later
         clst_exp = exp(index + near_reti + area_cat), # scores as exponential
         clst_exp2 = exp(index + near_reti2 + area_cat), # scores as exponential (not used)
         ) %>%
  st_make_valid() # repair invalid geometry

bf_cluster %>%
  st_drop_geometry() %>%
  count(near_reti2, area_cat, index, clst_exp2) %>%
  arrange(desc(near_reti2)) %>%
  print(n=100)

# bf_cluster %>%
#   st_drop_geometry() %>%
#   count(cluster, index, near_reti) %>%
#   print(n=100)

# tm_shape(bf_cluster) +
#   tm_fill("near_reti")

# tm_shape(bf_cluster) + 
#   tm_fill("area_cat")

# the cluster variable is what should be used in QGIS clustering method

# check that all building geometry is now valid (s/b all TRUE)
table(st_is_valid(bf_cluster))


# 6. Create descriptive vars from PLUTO & HPD ---------------------------------

# clean up hpd contact information for registered buildings
## start by subsetting the data based on BINs in the bldg footprint data
bins <- bf_noflaw9 %>%
  distinct(bin) %>%
  pull(bin)

hpd_contacts_restructured <- hpd_regs %>%
  filter(bin %in% bins) %>%
  left_join(hpd_contacts, by = "registrationid") %>%
  mutate(bin = as.character(bin),
         name = paste(firstname, lastname),
         add = paste(businesshousenumber, businessstreetname, replace_na(businessapartment, ""), businesscity, businessstate, businesszip),
         type_simple = case_when(
           type == "Agent" ~ "agent",
           type == "CorporateOwner" ~ "owner",
           type == "HeadOfficer" ~ "head",
           type == "IndividualOwner" ~ "owner",
           type == "Officer" ~ "officer",
           type == "SiteManager" ~ "manager",
           TRUE ~ "other"
         )) %>%
  pivot_wider(id_cols = c(bin, registrationid),
              names_from = type_simple, 
              names_glue = "{type_simple}_{.value}",
              values_from = c(name, add),
              values_fn = max) %>% #keep first non-missing value
  select(-owner_name, -manager_add, -starts_with("other")) %>%
  ## we will add this dataframe to the main one in the next step
  arrange(bin, agent_name) %>% #sort records so substantive rows are on top
  distinct(bin, .keep_all = T) #deduplicate bin's with multiple registration id

# create lists of some of the bldg_class values we'll use in the case_when statement

# Note: A8 operates more like a condo than a single-family home, even if the buildings are separate.
# exclude it from the list of building classes here
A <- bf_noflaw9 %>% 
  st_drop_geometry() %>%
  count(bldgclass) %>%
  filter(grepl("^A[012345679]", bldgclass, ignore.case = TRUE)) %>%
  pull(bldgclass)

B <- bf_noflaw9 %>% 
  st_drop_geometry() %>%
  count(bldgclass) %>%
  filter(grepl("^B", bldgclass, ignore.case = TRUE)) %>%
  pull(bldgclass)

C <- bf_noflaw9 %>% 
  st_drop_geometry() %>%
  count(bldgclass) %>%
  filter(grepl("^C", bldgclass, ignore.case = TRUE)) %>%
  pull(bldgclass)

D <- bf_noflaw9 %>% 
  st_drop_geometry() %>%
  count(bldgclass) %>%
  filter(grepl("^D", bldgclass, ignore.case = TRUE)) %>%
  pull(bldgclass)

S <- bf_noflaw9 %>% 
  st_drop_geometry() %>%
  count(bldgclass) %>%
  filter(grepl("^S", bldgclass, ignore.case = TRUE)) %>%
  pull(bldgclass)

# join hpd data and pluto building type data
bf_noflaw12 <- bf_noflaw11 %>%
  left_join(hpd_contacts_restructured, by = "bin") %>%
  mutate(owner_cat = case_when(
    ownertype == "C" ~ "City-owned",
    ownertype == "M" ~ "Mixed city & private",
    ownertype == "O" ~ "State, federal, or public authority",
    ownertype == "P" ~ "Private",
    ownertype == "X" ~ "Tax-exempt property",
    is.na(ownertype) ~ "Unknown (likely private)"
  ),
  r_bldgtype = case_when(
    bldgclass %in% c(A) ~ "single family",
    bldgclass %in% c('A8') & unitsres > 1 ~ "coop",
    bldgclass %in% c('C6','C8','D0','D4') ~ "coop",
    bldgclass %in% c('R1','R2','R3','R4','R6','R9','RD','RR') ~ "condo",
    bldgclass %in% c(B, C, D) ~ "multiple unit",
    bldgclass %in% c(S) & unitsres > 1 ~ "multiple unit",
    TRUE ~ "not residential"),
  residential = ifelse(r_bldgtype != "not residential", 1, 0))

# check hpd contact information join
bf_noflaw12 %>%
  st_drop_geometry() %>%
  select(registrationid, ends_with("_add"), ends_with("_name")) %>%
  sapply(function(x) sum(is.na(x)))

# missing for most records, but the join seems to have worked for some of them

# check building type var creation
bf_noflaw12 %>%
  st_drop_geometry() %>%
  group_by(r_bldgtype) %>%
  summarise(n_bldgs = n(),                              # num tax lots
            n_na_unit = sum(is.na(unitsres)),           # num rows missing units_res
            min_units = min(unitsres, na.rm = TRUE),    # min units_res
            max_units = max(unitsres, na.rm = TRUE),    # max units_res
            med_units = median(unitsres, na.rm = TRUE)) # median units_res

bf_noflaw12 %>%
  st_drop_geometry() %>%
  mutate(anyres = ifelse(!is.na(unitsres) & unitsres > 0, 1, 0)) %>%
  group_by(residential, r_bldgtype) %>%
  summarise(n = n(),
            nres = sum(anyres))

# 7. Save permanent files -----------------------------------------------------

# check: var names must be no more than 10 characters
names(bf_cluster) %>%
  as.data.frame() %>%
  mutate(nchar = nchar(.)) %>%
  arrange(desc(nchar))

# write index and cluster scores as shapefile ----
st_write(bf_cluster, "dat/suitability index/nyc_suitability_index.shp", delete_dsn = T)

# the next step is for a hot spot analysis to be run in ArcGIS Pro using this layer
## the hot spot output is then joined to this layer and saved as 
## suitability_index_hotspot.shp

# export underlying data as .csv
bf_csv <- bf_noflaw12 %>%
  st_drop_geometry() %>%
  select(bin, address,
         # include variables underlying the flag values
         heightroof, shape_area, zonedist1, ratio_residfar, histdist, ElcPrd_MWh, ownername, zipcode,
         bct2020, ends_with("_name"), ends_with("_add"), owner_cat, r_bldgtype, residential) %>%
  left_join(st_drop_geometry(bf_index), by = "bin")

# export data behind index scores as csv ----
write_csv(bf_csv, "dat/nyc_bldg_fp_index_and_elecprod.csv")




