# Visualise the outputs

options(digits = 2, scipen = 999)

# Load all packages
source("analysis/settings_packages.R")

# 1. Total forest plot: -----
all_binomial <- read_csv(here("output", "st04_02_all_factors_binomial.csv")) %>% 
      filter(term != "(Intercept)") %>% 
      dplyr::select(term, estimate, lci, hci, p.value) 

all_binomial <- all_binomial%>% mutate(
      Factors = case_when(
            term == "age" ~ "Age",
            term == "sexfemale" ~ "Female",
            term == "bmi_catUnderweight" ~ "Underweight",
            term == "bmi_catOverweight" ~ "Overweight",
            term == "bmi_catObese" ~ "Obese",
            term == "ethnicity_6Mixed" ~ "Mixed",
            term == "ethnicity_6South Asian" ~ "South Asian",
            term == "ethnicity_6Black" ~ "Black",
            term == "ethnicity_6Other" ~ "Other",
            term == "imd_q52_deprived" ~ "2nd deprived",
            term == "imd_q53_deprived" ~ "3rd deprived",
            term == "imd_q54_deprived" ~ "4th deprived",
            term == "imd_q5most_deprived" ~ "Most deprived",
            term == "regionEast" ~ "East",
            term == "regionEast Midlands" ~ "East Midlands",
            term == "regionNorth East" ~ "North East",
            term == "regionNorth West" ~ "North West",
            term == "regionSouth East" ~ "South East",
            term == "regionSouth West" ~ "South West",
            term == "regionWest Midlands"~ "West Midlands",
            term == "regionYorkshire and The Humber" ~ "Yorkshire and The Humber",
            term == "cov_asthmaTRUE" ~ "Had asthma",
            term == "cov_mental_healthTRUE" ~ "Had mental health isses",
            term == "previous_covid_hospTRUE" ~ "Had previous COVID hospital admission",
            term == "cov_covid_vax_n_cat1 dose"~ "Received one dose",
            term == "cov_covid_vax_n_cat2 doses"~ "Received two doses",
            term == "cov_covid_vax_n_cat3 or more doses"~ "Received three or more doses",
            term == "number_comorbidities_cat1" ~ "One comorbidities",
            term == "number_comorbidities_cat2" ~ "Two comorbidities",
            term == "number_comorbidities_cat3" ~ "Three or more comorbidities",
            term == "exposureLong covid exposure" ~ "Long COVID")) %>% 
      mutate(Categories = case_when(
            str_detect(term, "age") ~ "Age",
            str_detect(term, "sex") ~ "Sex",
            str_detect(term, "bmi_") ~ "BMI categories",
            str_detect(term, "ethnicity_") ~ "Ethnicity",
            str_detect(term, "imd_q") ~ "Index for Multiple Deprivation",
            str_detect(term, "region") ~ "Region",
            str_detect(term, "previous_covid_") ~ "Hospitalisation",
            str_detect(term, "cov_covid_vax_n_") ~ "COVID vaccine doses",
            str_detect(term, "cov_asthma") ~ "Asthma",
            str_detect(term, "cov_mental_health")  ~ "Mental health conditions",
            str_detect(term, "number_comorbidities_cat") ~ "Comorbidities",
            Factors == "Long COVID" ~ "Exposure")) %>% 
      dplyr::select(Categories, Factors, estimate, lci, hci) 


all_binomial <- all_binomial %>%
      group_by(Categories) %>% 
      mutate(Order = row_number()) %>% 
      ungroup %>% 
      add_row(Categories = "Exposure",
              Factors = "Comparator",
              estimate = 1, lci =1, hci =1,
              Order = 0) %>% 
      add_row(Categories = "Sex",
              Factors = "Male",
              estimate = 1, lci =1, hci =1,
              Order = 0) %>% 
      add_row(Categories = "BMI categories", 
              Factors = "Normal BMI",
              estimate = 1, lci =1, hci =1,
              Order = 0) %>% 
      add_row(Categories = "Ethnicity", 
              Factors = "White ethnicity",
              estimate = 1, lci =1, hci =1,
              Order = 0) %>% 
      add_row(Categories = "Index for Multiple Deprivation", 
              Factors = "Least deprived",
              estimate = 1, lci =1, hci =1,
              Order = 0) %>% 
      add_row(Categories = "Region", 
              Factors = "London",
              estimate = 1, lci =1, hci =1,
              Order = 0) %>% 
      add_row(Categories = "Asthma", 
              Factors = "No asthma",
              estimate = 1, lci =1, hci =1,
              Order = 0) %>% 
      add_row(Categories = "Mental health conditions", 
              Factors = "No mental health conditions",
              estimate = 1, lci =1, hci =1,
              Order = 0) %>% 
      add_row(Categories = "COVID vaccine doses", 
              Factors = "Did not receive COVID vaccines",
              estimate = 1, lci =1, hci =1,
              Order = 0) %>% 
      add_row(Categories = "Comorbidities", 
              Factors = "Did not have comorbidities",
              estimate = 1, lci =1, hci =1,
              Order = 0) %>% 
      mutate(cat_order = case_when(
            Categories == "Age" ~ 1,
            Categories == "Sex" ~ 2,
            Categories == "Ethnicity" ~ 3,
            Categories == "Region" ~ 4,
            Categories == "Index for Multiple Deprivation" ~ 5,
            Categories == "BMI categories"~ 6,
            Categories == "Asthma"~ 7,
            Categories == "Mental health conditions"~ 8,
            Categories == "Comorbidities" ~ 9,
            Categories == "Hospitalisation"~ 10,
            Categories == "COVID vaccine doses" ~ 11)) %>% 
      arrange(cat_order, Order) %>% 
      mutate(Categories = ifelse(Order == 0, Categories, " ")) %>% 
      mutate(Categories = ifelse(Factors == "Age", "Age", Categories)) %>% 
      mutate(Categories = ifelse(Factors == "Had previous COVID hospital admission", 
                                 "Hospitalisation", Categories)) %>% 
      dplyr::select(Categories, Factors, estimate, lci, hci)


all_binomial$`   First part      `  <- " "
all_binomial <- relocate(all_binomial, `   First part      `  , .after = Factors)



all_binomial$`OR (95% CI)` <- sprintf("%.2f (%.2f - %.2f)",
                                      all_binomial$estimate,  
                                      all_binomial$lci,  
                                      all_binomial$hci)
all_binomial <- relocate(all_binomial, `OR (95% CI)` , .after = `   First part      `)


# Forest plot: 

(all_bi_forestplot <- forest(
      data = all_binomial[,1:4],
      est = all_binomial$estimate,
      lower = all_binomial$lci,
      upper = all_binomial$hci,
      ci_column = 3,
      xlim = c(0, 4),
      ref_line = 1
))

# Second part hurdle: 
all_hurdle <- read_csv("output/st04_02_all_factors_hurdle.csv") %>% 
      filter(term != "(Intercept):2" & term != "(Intercept):1") %>% 
      dplyr::select(term, estimate, lci, hci, p.value) %>% 
      mutate(
            Factors = case_when(
                  term == "age" ~ "Age",
                  term == "sexfemale" ~ "Female",
                  term == "bmi_catUnderweight" ~ "Underweight",
                  term == "bmi_catOverweight" ~ "Overweight",
                  term == "bmi_catObese" ~ "Obese",
                  term == "ethnicity_6Mixed" ~ "Mixed",
                  term == "ethnicity_6South Asian" ~ "South Asian",
                  term == "ethnicity_6Black" ~ "Black",
                  term == "ethnicity_6Other" ~ "Other",
                  term == "imd_q52_deprived" ~ "2nd deprived",
                  term == "imd_q53_deprived" ~ "3rd deprived",
                  term == "imd_q54_deprived" ~ "4th deprived",
                  term == "imd_q5most_deprived" ~ "Most deprived",
                  term == "regionEast" ~ "East",
                  term == "regionEast Midlands" ~ "East Midlands",
                  term == "regionNorth East" ~ "North East",
                  term == "regionNorth West" ~ "North West",
                  term == "regionSouth East" ~ "South East",
                  term == "regionSouth West" ~ "South West",
                  term == "regionWest Midlands"~ "West Midlands",
                  term == "regionYorkshire and The Humber" ~ "Yorkshire and The Humber",
                  term == "cov_asthmaTRUE" ~ "Had asthma",
                  term == "cov_mental_healthTRUE" ~ "Had mental health isses",
                  term == "previous_covid_hospTRUE" ~ "Had previous COVID hospital admission",
                  term == "cov_covid_vax_n_cat1 dose"~ "Received one dose",
                  term == "cov_covid_vax_n_cat2 doses"~ "Received two doses",
                  term == "cov_covid_vax_n_cat3 or more doses"~ "Received three or more doses",
                  term == "number_comorbidities_cat1" ~ "One comorbidities",
                  term == "number_comorbidities_cat2" ~ "Two comorbidities",
                  term == "number_comorbidities_cat3" ~ "Three or more comorbidities",
                  term == "exposureLong covid exposure" ~ "Long COVID")) %>% 
      mutate(Categories = case_when(
            str_detect(term, "age") ~ "Age",
            str_detect(term, "sex") ~ "Sex",
            str_detect(term, "bmi_") ~ "BMI categories",
            str_detect(term, "ethnicity_") ~ "Ethnicity",
            str_detect(term, "imd_q") ~ "Index for Multiple Deprivation",
            str_detect(term, "region") ~ "Region",
            str_detect(term, "previous_covid_") ~ "Hospitalisation",
            str_detect(term, "cov_covid_vax_n_") ~ "COVID vaccine doses",
            str_detect(term, "cov_asthma") ~ "Asthma",
            str_detect(term, "cov_mental_health")  ~ "Mental health conditions",
            str_detect(term, "number_comorbidities_cat") ~ "Comorbidities",
            Factors == "Long COVID" ~ "Exposure")) %>% 
      dplyr::select(Categories, Factors, estimate, lci, hci) 




all_hurdle <- all_hurdle %>%
      group_by(Categories) %>% 
      mutate(Order = row_number()) %>% 
      ungroup %>% 
      add_row(Categories = "Exposure",
              Factors = "Comparator",
              estimate = 1, lci =1, hci =1,
              Order = 0) %>% 
      add_row(Categories = "Sex",
              Factors = "Male",
              estimate = 1, lci =1, hci =1,
              Order = 0) %>% 
      add_row(Categories = "BMI categories", 
              Factors = "Normal BMI",
              estimate = 1, lci =1, hci =1,
              Order = 0) %>% 
      add_row(Categories = "Ethnicity", 
              Factors = "White ethnicity",
              estimate = 1, lci =1, hci =1,
              Order = 0) %>% 
      add_row(Categories = "Index for Multiple Deprivation", 
              Factors = "Least deprived",
              estimate = 1, lci =1, hci =1,
              Order = 0) %>% 
      add_row(Categories = "Region", 
              Factors = "London",
              estimate = 1, lci =1, hci =1,
              Order = 0) %>% 
      add_row(Categories = "Asthma", 
              Factors = "No asthma",
              estimate = 1, lci =1, hci =1,
              Order = 0) %>% 
      add_row(Categories = "Mental health conditions", 
              Factors = "No mental health conditions",
              estimate = 1, lci =1, hci =1,
              Order = 0) %>% 
      add_row(Categories = "COVID vaccine doses", 
              Factors = "Did not receive COVID vaccines",
              estimate = 1, lci =1, hci =1,
              Order = 0) %>% 
      add_row(Categories = "Comorbidities", 
              Factors = "Did not have comorbidities",
              estimate = 1, lci =1, hci =1,
              Order = 0) %>% 
      mutate(cat_order = case_when(
            Categories == "Age" ~ 1,
            Categories == "Sex" ~ 2,
            Categories == "Ethnicity" ~ 3,
            Categories == "Region" ~ 4,
            Categories == "Index for Multiple Deprivation" ~ 5,
            Categories == "BMI categories"~ 6,
            Categories == "Asthma"~ 7,
            Categories == "Mental health conditions"~ 8,
            Categories == "Comorbidities" ~ 9,
            Categories == "Hospitalisation"~ 10,
            Categories == "COVID vaccine doses" ~ 11)) %>% 
      arrange(cat_order, Order) %>% 
      mutate(Categories = ifelse(Order == 0, Categories, " ")) %>% 
      mutate(Categories = ifelse(Factors == "Age", "Age", Categories)) %>% 
      mutate(Categories = ifelse(Factors == "Had previous COVID hospital admission", 
                                 "Hospitalisation", Categories)) %>% 
      dplyr::select(Categories, Factors, estimate, lci, hci)




all_hurdle$`   Second part      `  <- " "
all_hurdle <- relocate(all_hurdle, `   Second part      `  , .after = Factors)



all_hurdle$`RR (95% CI)` <- sprintf("%.2f (%.2f - %.2f)",
                                    all_hurdle$estimate,  
                                    all_hurdle$lci,  
                                    all_hurdle$hci)
all_hurdle <- relocate(all_hurdle, `RR (95% CI)` , .after = `   Second part      `)

(all_hurdle_forestplot <- forest(
      data = all_hurdle[,1:4],
      est = all_hurdle$estimate,
      lower = all_hurdle$lci,
      upper = all_hurdle$hci,
      ci_column = 3,
      xlim = c(0, 4),
      ref_line = 1
))




# Plot two parts together:
all_part_1 <- all_binomial
all_part_2 <- all_hurdle %>% 
      rename(      estimate2 = estimate, 
                   lci2 = lci,
                   hci2 = hci)

all_combine_p_1_2 <- full_join(all_part_1, all_part_2)

all_combine_p_1_2[,c(1,2,3,4,8,9)] %>% names

tm <- forest_theme(core=list(bg_params=list(fill = c("#FFFFFF"))))

all_two_forest <- forest(
      data = all_combine_p_1_2[,c(1,2,3,4,8,9)],
      est = list(all_combine_p_1_2$estimate, all_combine_p_1_2$estimate2),
      lower = list(all_combine_p_1_2$lci, all_combine_p_1_2$lci2),
      upper = list(all_combine_p_1_2$hci, all_combine_p_1_2$hci2),
      ci_column = c(3, 5),
      xlim = list(c(0, 8), c(0, 2.5)),
      ref_line = 1,
      theme = tm)
plot(all_two_forest)


ggsave(all_two_forest, file = "output/st04_03_all_factors.svg",
       device = "svg",
       width=20, height=14, units = "in", dpi = 300)
