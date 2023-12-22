# Exploratory script

# The PURPOSE of this .R script is to explore various data sources to better 
# understand data availability and utility

# 0. Packages ------

library(tidyverse)
library(janitor)
library(clipr)
library(sf)

# 1. NYSERDA Solar Project data ----------

nyserdaurl <- URLencode("https://data.ny.gov/resource/3x8r-34rs.csv?$query=SELECT * 
                        WHERE electric_utility = 'Consolidated Edison' AND 
                        incorporated_municipality = 'New York' AND
                        community_distributed_generation = 'Yes'
                        LIMIT 1000000")

nyserda <- read_csv(nyserdaurl)

nrow(nyserda)
# 684 community solar projects

nyserda %>% count(project_status)
#             n
# Complete	355
# Pipeline	329

nyserda %>%
  group_by(project_status) %>%
  summarise(sum = sum(expected_kwh_annual_production, na.rm = T))

## 1a. Figuring out which sites to include in the project ---------------------
# look into the expected kWh production to get a sense of what they use as a threshold 

# summary statistics
nyserda %>% 
  summarise(min = min(expected_kwh_annual_production),
            max = max(expected_kwh_annual_production),
            mean = mean(expected_kwh_annual_production),
            q25 = quantile(expected_kwh_annual_production, 0.25),
            median = median(expected_kwh_annual_production),
            q75 = quantile(expected_kwh_annual_production, 0.75))

q95 <- quantile(nyserda$expected_kwh_annual_production, 0.95)

# remove top 5% to look at the spread of smaller projects
nyserda95 <- nyserda %>%
  filter(expected_kwh_annual_production <= q95)

nyserda95 %>%
  # look at just since 2019
  filter(year(date_application_received) >= 2019) %>%
  ggplot(aes(x = expected_kwh_annual_production)) + 
  geom_histogram(bins = 50) + 
  facet_grid(~project_status)

simple <- nyserda %>%
  select(project_number, expected_kwh_annual_production)

## 1b. Export NYSERDA data & plot it on the map -------------------------------

# write_csv(nyserda, "dat/nyserda projects/nyserda projects.csv")

nyserda_shp <- st_as_sf(nyserda, wkt = "georeference")

