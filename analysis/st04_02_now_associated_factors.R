# Load previous data management
source("analysis/dm03_5_matched_pivot_long.R")


# Show the factors associated with increased outcomes among:
# 1. All participants 
# 2. People with long COVID
# 3. People without long COVID

# 0. Common part:  -----
# # Add covariates for adjustment
for_covariates <- matched_data_ts %>% distinct(patient_id, exposure, .keep_all = T) %>% 
      dplyr::select("patient_id",     
                    "exposure",           
                    "age", "age_cat",               
                    "sex",                     
                    "bmi_cat",
                    "ethnicity_6",             
                    "imd_q5",                  
                    "region",      
                    "cov_asthma",
                    "cov_mental_health",   
                    "previous_covid_hosp",     
                    "cov_covid_vax_n_cat",     
                    "number_comorbidities_cat")

for_covariates$sex <- relevel(for_covariates$sex, ref = "male")
for_covariates$bmi_cat <- relevel(for_covariates$bmi_cat, ref = "Normal Weight")
for_covariates$ethnicity_6 <- relevel(for_covariates$ethnicity_6, ref = "White")
for_covariates$imd_q5 <- relevel(for_covariates$imd_q5, ref = "least_deprived")
for_covariates$region <- relevel(for_covariates$region, ref = "London" )
for_covariates$cov_mental_health <- relevel(for_covariates$cov_mental_health, ref = "FALSE")
for_covariates$previous_covid_hosp <- relevel(for_covariates$previous_covid_hosp, ref = "FALSE")
for_covariates$previous_covid_hosp <- relevel(for_covariates$previous_covid_hosp, ref = "FALSE")
for_covariates$cov_covid_vax_n_cat <- relevel(for_covariates$cov_covid_vax_n_cat, ref = "0 dose")
for_covariates$number_comorbidities_cat <- relevel(for_covariates$number_comorbidities_cat, ref = "0")

# Stats: two part (Hurdle) model -----

# Use a function to organised the regression outputs to get RR and CI:
# Tidy binomial model:
binomial_tidy_fn <- function(bi_reg){
      bi_results <- bi_reg %>% tidy() %>% mutate(
            model = "binomial",
            lci = exp(estimate - 1.96*std.error),
            hci = exp(estimate + 1.96*std.error),
            estimate = exp(estimate)) %>% 
            dplyr::select(model, term, estimate, lci, hci, p.value)
      return(bi_results)
}

# tidy vglm outputs:
positive_nb_tidy_fu <- function(vg_reg){
      
      t1 <- vg_reg %>%summary
      t2 <- t1@coef3 %>% as.data.frame()
      t2$term <- rownames(t2)
      results <- t2 %>% mutate(
            lci = exp(Estimate - 1.96*`Std. Error`),
            hci = exp(Estimate + 1.96*`Std. Error`),
            estimate = exp(Estimate),
            p.value = `Pr(>|z|)`,
            model = "Positive Negative Bionomial") %>% 
            dplyr::select(model, term, estimate, lci, hci, p.value)
      return(results)
}

# Predict average outcome:
predict_visit_fn <- function(dataset, part_1, part_2){
      input <- dataset %>% mutate(follow_up = 360)
      
      input$non_zero_prob <- predict(part_1, 
                                     newdata = input, 
                                     type = "response")
      
      p2 <- predict(part_2, 
                    newdata = input, 
                    type = "link", 
                    se.fit = T)
      
      input<- bind_cols(
            input, 
            (p2$fitted.values %>% as.data.frame() %>% 
                   dplyr::select(`loglink(munb)`) %>% 
                   rename(p_visits = `loglink(munb)`)),
            (p2$se.fit %>% as.data.frame()%>% 
                   dplyr::select(`loglink(munb)`) %>% 
                   rename(p_se = `loglink(munb)`))
      )
      input_c <- input %>% 
            mutate(c_visits = exp(p_visits)*non_zero_prob,
                   c_lci = exp(p_visits - 1.96*p_se)*non_zero_prob,
                   c_hci = exp(p_visits + 1.96*p_se)*non_zero_prob) %>% 
            dplyr::select(exposure, c_visits, c_lci, c_hci)
      
      # summarise the results
      results <- input_c %>% 
            summarise(
                  visits = mean(c_visits, na.rm =T),
                  lci = mean(c_lci, na.rm =T),
                  hci = mean(c_hci, na.rm = T)) 
}

# 1. All partricipants -------------------

# 12 months: 
# follow 12 months (regardless their exposure status)
matched_data_all_12m <- matched_data_ts %>% 
      filter(!is.na(follow_up_time)) %>% 
      group_by(patient_id) %>% 
      summarise(
            visits = sum(monthly_visits),
            follow_up = sum(follow_up_time)) %>% 
      ungroup()

# add other covariates:
matched_data_all_12m <- left_join(matched_data_all_12m, for_covariates,
                                 by = c("patient_id" = "patient_id"))

# set binary visit outcomes
all_complete_12m <- matched_data_all_12m[complete.cases(matched_data_all_12m),] %>% 
      mutate(visits_binary = ifelse(visits>0, 1, 0))

# Model:

# 12 Months
all_binomial_12m <- glm(visits_binary ~ offset(log(follow_up)) +
                              age + sex + bmi_cat + ethnicity_6 + imd_q5 + region + cov_asthma + cov_mental_health +
                              previous_covid_hosp + cov_covid_vax_n_cat +number_comorbidities_cat, 
                        data = all_complete_12m,
                        family=binomial(link="logit")) 

# 12 months
all_nb_12m <- vglm(visits ~ offset(log(follow_up))+
                         age + sex + bmi_cat + ethnicity_6 + imd_q5 + region + cov_asthma + cov_mental_health +
                         previous_covid_hosp + cov_covid_vax_n_cat +number_comorbidities_cat, 
                   family = posnegbinomial(),
                   data = subset(all_complete_12m, visits_binary > 0))

# Combine and organised regression outputs
all_binomial_outputs <- binomial_tidy_fn(all_binomial_12m) %>% 
      mutate(time="12 months") %>% 
      mutate(Adjustment = "Adjusted",
             Data = "Total")

# Organise the second part outputs:
all_hurdle_outputs <- positive_nb_tidy_fu(all_nb_12m) %>% 
      mutate(time="12 months") %>% 
      mutate(Adjustment = "Adjusted",
             Data = "Total")

# save outputs:
all_binomial_outputs %>% write_csv(here("output", "st03_05_sub_all_factors_binomial.csv"))
all_hurdle_outputs %>% write_csv(here("output", "st03_05_sub_all_factors_hurdle.csv"))


# Obtain results in absolute scale:

average_visits_total <- predict_visit_fn(dataset = all_complete_12m,
                                             part_1 = all_binomial_12m,
                                             part_2 = all_nb_12m) %>% 
      mutate(data_subset="All") %>% relocate(data_subset)

# 2. LC only: ------

# Data management for modeling:: 
# Collapsing data by summarising the visits and follow-up time, and 
# generate three datasets for follow-up 3m, 6m, and 12m

# # 3 months
matched_data_lc_3m <- matched_data_ts %>% subset(exposure == "Long covid exposure") %>% 
      filter(month %in% c(1,2,3)& !is.na(follow_up_time)) %>% 
      group_by(patient_id, exposure) %>% 
      summarise(
            visits = sum(monthly_visits),
            follow_up = sum(follow_up_time)) %>% 
      ungroup()

# # 6 months
matched_data_lc_6m <- matched_data_ts %>% subset(exposure == "Long covid exposure") %>% 
      filter(month %in% c(1,2,3,4,5,6)& !is.na(follow_up_time)) %>% 
      group_by(patient_id, exposure) %>% 
      summarise(
            visits = sum(monthly_visits),
            follow_up = sum(follow_up_time)) %>% 
      ungroup()

# follow 12 months 
matched_data_lc_12m <- matched_data_ts %>% subset(exposure == "Long covid exposure") %>% 
      filter(!is.na(follow_up_time)) %>% 
      group_by(patient_id, exposure) %>% 
      summarise(
            visits = sum(monthly_visits),
            follow_up = sum(follow_up_time)) %>% 
      ungroup()



# # add covariates back to the summarised data frame
matched_data_lc_3m <- left_join(matched_data_lc_3m, for_covariates,
                               by = c("patient_id" = "patient_id", "exposure" = "exposure"))

matched_data_lc_6m <- left_join(matched_data_lc_6m, for_covariates,
                             by = c("patient_id" = "patient_id", "exposure" = "exposure"))

matched_data_lc_12m <- left_join(matched_data_lc_12m, for_covariates,
                             by = c("patient_id" = "patient_id", "exposure" = "exposure"))

# correct the level of exposure groups
matched_data_lc_3m$exposure <- relevel(matched_data_lc_3m$exposure, ref = "Comparator")
matched_data_lc_6m$exposure <- relevel(matched_data_lc_6m$exposure, ref = "Comparator")
matched_data_lc_12m$exposure <- relevel(matched_data_lc_12m$exposure, ref = "Comparator")


# Adjusted hurdle model: 
# First need to clean the data by excluding obs with NA in variables:
adj_complete_3m <- matched_data_lc_3m[complete.cases(matched_data_lc_3m),] %>% 
      mutate(visits_binary = ifelse(visits>0, 1, 0))
adj_complete_6m <- matched_data_lc_6m[complete.cases(matched_data_lc_6m),] %>% 
      mutate(visits_binary = ifelse(visits>0, 1, 0))
adj_complete_12m <- matched_data_lc_12m[complete.cases(matched_data_lc_12m),] %>% 
      mutate(visits_binary = ifelse(visits>0, 1, 0))


# Hurdle model part 1: binomial model:
# 3 Months
adj_binomial_3m <- glm(visits_binary ~ offset(log(follow_up)) +
                             age + sex + bmi_cat + ethnicity_6 + imd_q5 + region + cov_asthma + cov_mental_health +
                             previous_covid_hosp + cov_covid_vax_n_cat +number_comorbidities_cat, 
                       data = adj_complete_3m,
                       family=binomial(link="logit")) 

# 6 Months
adj_binomial_6m <- glm(visits_binary ~ offset(log(follow_up)) +
                             age + sex + bmi_cat + ethnicity_6 + imd_q5 + region + cov_asthma + cov_mental_health +
                             previous_covid_hosp + cov_covid_vax_n_cat +number_comorbidities_cat, 
                       data = adj_complete_6m,
                       family=binomial(link="logit")) 

# 12 Months
adj_binomial_12m <- glm(visits_binary ~ offset(log(follow_up)) +
                              age + sex + bmi_cat + ethnicity_6 + imd_q5 + region + cov_asthma + cov_mental_health +
                              previous_covid_hosp + cov_covid_vax_n_cat +number_comorbidities_cat, 
                        data = adj_complete_12m,
                        family=binomial(link="logit")) 

# Hurdle model part 2: positive negative binomial model:

# Positive negative binomial
# 3 months
adj_nb_3m <- vglm(visits ~ offset(log(follow_up))+
                        age + sex + bmi_cat + ethnicity_6 + imd_q5 + region + cov_asthma + cov_mental_health +
                        previous_covid_hosp + cov_covid_vax_n_cat +number_comorbidities_cat, 
                  family = posnegbinomial(),
                  data = subset(adj_complete_3m, visits_binary > 0))

# 6 months 
adj_nb_6m <- vglm(visits ~ offset(log(follow_up))+
                        age + sex + bmi_cat + ethnicity_6 + imd_q5 + region + cov_asthma + cov_mental_health +
                        previous_covid_hosp + cov_covid_vax_n_cat +number_comorbidities_cat, 
                  family = posnegbinomial(),
                  data = subset(adj_complete_6m, visits_binary > 0))

# 12 months
adj_nb_12m <- vglm(visits ~ offset(log(follow_up))+
                         age + sex + bmi_cat + ethnicity_6 + imd_q5 + region + cov_asthma + cov_mental_health +
                         previous_covid_hosp + cov_covid_vax_n_cat +number_comorbidities_cat, 
                   family = posnegbinomial(),
                   data = subset(adj_complete_12m, visits_binary > 0))


# Combine and organised regression outputs
adj_binomial_outputs <-bind_rows(
      (binomial_tidy_fn(adj_binomial_3m) %>% mutate(time="3 months")),
      (binomial_tidy_fn(adj_binomial_6m) %>% mutate(time="6 months")),
      (binomial_tidy_fn(adj_binomial_12m) %>% mutate(time="12 months"))
) %>% mutate(Adjustment = "Adjusted")

# Organise the second part outputs:
adj_hurdle_outputs <- bind_rows(
      (positive_nb_tidy_fu(adj_nb_3m) %>% mutate(time="3 months")),
      (positive_nb_tidy_fu(adj_nb_6m) %>% mutate(time="6 months")),
      (positive_nb_tidy_fu(adj_nb_12m) %>% mutate(time="12 months"))
) %>% mutate(Adjustment = "Adjusted")

# Save the detailed outputs to a text file:
sink(here("output", "st03_05_subgroup_lc_only_reg_summary.txt"))
print("# Adjusted binomial model output part 1 ---------")
print(summary(adj_binomial_12m))
print("# Adjusted hurdle model output part 2 ---------")
print(summary(adj_nb_12m))
sink()

# Combine total outputs and save:

adj_binomial_outputs %>% write_csv(here("output", "st03_05_sub_lc_only_binomial.csv"))
adj_hurdle_outputs %>% write_csv(here("output", "st03_05_sub_lc_only_hurdle.csv"))


# results in asolute scale: 
average_visits_lc_only <- predict_visit_fn(dataset = adj_complete_12m,
                                           part_1 = adj_binomial_12m,
                                           part_2 = adj_nb_12m) %>% 
      mutate(data_subset="LC only") %>% relocate(data_subset)



# 3. Non-LC group subset:------

# follow 12 months 
matched_data_nolc_12m <- matched_data_ts %>% subset(exposure != "Long covid exposure") %>% 
      filter(!is.na(follow_up_time)) %>% 
      group_by(patient_id, exposure) %>% 
      summarise(
            visits = sum(monthly_visits),
            follow_up = sum(follow_up_time)) %>% 
      ungroup()

# add covariates and relevel:

matched_data_nolc_12m <- left_join(matched_data_nolc_12m, for_covariates,
                                 by = c("patient_id" = "patient_id", "exposure" = "exposure"))
matched_data_nolc_12m$exposure <- relevel(matched_data_nolc_12m$exposure, ref = "Comparator")


# Adjusted hurdle model: 
# First need to clean the data by excluding obs with NA in variables:
nolc_complete_12m <- matched_data_nolc_12m[complete.cases(matched_data_nolc_12m),] %>% 
      mutate(visits_binary = ifelse(visits>0, 1, 0))



# Hurdle model: 

# 12 Months
nolc_binomial_12m <- glm(visits_binary ~ offset(log(follow_up)) +
                              age + sex + bmi_cat + ethnicity_6 + imd_q5 + region + cov_asthma + cov_mental_health +
                              previous_covid_hosp + cov_covid_vax_n_cat +number_comorbidities_cat, 
                        data = nolc_complete_12m,
                        family=binomial(link="logit")) 

# 12 months
nolc_nb_12m <- vglm(visits ~ offset(log(follow_up))+
                         age + sex + bmi_cat + ethnicity_6 + imd_q5 + region + cov_asthma + cov_mental_health +
                         previous_covid_hosp + cov_covid_vax_n_cat +number_comorbidities_cat, 
                   family = posnegbinomial(),
                   data = subset(nolc_complete_12m, visits_binary > 0))

# Combine and organised regression outputs
nolc_binomial_outputs <- binomial_tidy_fn(nolc_binomial_12m) %>% 
      mutate(time="12 months") %>% 
      mutate(Adjustment = "Adjusted",
             Data = "No long COVID")

# Organise the second part outputs:
nolc_hurdle_outputs <- positive_nb_tidy_fu(nolc_nb_12m) %>% 
      mutate(time="12 months") %>% 
      mutate(Adjustment = "Adjusted",
             Data = "No long COVID")

# save outputs:
nolc_binomial_outputs %>% write_csv(here("output", "st03_05_sub_nolc_binomial.csv"))
nolc_hurdle_outputs %>% write_csv(here("output", "st03_05_sub_nolc_hurdle.csv"))


# results in absolute scale:
average_visits_nolc <- predict_visit_fn(dataset = nolc_complete_12m,
                                        part_1 = nolc_binomial_12m,
                                        part_2 = nolc_nb_12m) %>% 
      mutate(data_subset="No LC") %>% relocate(data_subset)



# 4. Combine the absolute scales outputs: -----
bind_rows(
      average_visits_total,
      average_visits_lc_only,
      average_visits_nolc) %>% 
      write_csv(here("output", "st03_05_sub_predicted_visits.csv"))



# Summarize the datasets for output checking: -----

# Logit model count:
bi_model_count_fn <- function(data){
      
      data %>% group_by(exposure) %>% 
            summarise(
                  non_zero_count = sum(visits_binary > 0),
                  zero_count = sum(visits_binary == 0),
                  n = n()
            )
}

# Hurdle model count:
hurdle_model_count_fn <- function(data){
      
      data %>% filter(visits_binary>0) %>% 
            summarise(
                  mean_visit = mean(visits),
                  min_visit = min(visits),
                  max_visit = max(visits),
                  n = n(),
                  demonimator = sum(follow_up))
}



# Summarise model data: Long covid only group
bind_rows(
      bi_model_count_fn(all_complete_12m) %>% mutate(time = "12m") %>% mutate(model = "All factors"),
      bi_model_count_fn(adj_complete_3m) %>% mutate(time = "3m") %>% mutate(model = "LC only"),
      bi_model_count_fn(adj_complete_6m) %>% mutate(time = "6m") %>% mutate(model = "LC only"),
      bi_model_count_fn(adj_complete_12m) %>% mutate(time = "12m") %>% mutate(model = "LC only"),
      bi_model_count_fn(nolc_complete_12m) %>% mutate(time = "12m") %>% mutate(model = "No LC only")) %>%
      write_csv("output/st03_05_sub_groups_bi_model_counts.csv")

bind_rows(
      hurdle_model_count_fn(all_complete_12m) %>% mutate(time = "12m") %>% mutate(model = "All factors"),
      hurdle_model_count_fn(adj_complete_3m) %>% mutate(time = "3m") %>% mutate(model = "LC only"),
      hurdle_model_count_fn(adj_complete_6m) %>% mutate(time = "6m") %>% mutate(model = "LC only"),
      hurdle_model_count_fn(adj_complete_12m) %>% mutate(time = "12m") %>% mutate(model = "LC only"),
      hurdle_model_count_fn(adj_complete_12m) %>% mutate(time = "12m") %>% mutate(model = "No LC only")) %>% 
      write_csv("output/st03_05_sub_lc_only_hurdle_model_counts.csv")
