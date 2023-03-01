from databuilder.ehrql import codelist_from_csv

# 1. Long COVID
# # import different long COVID codelists:
long_covid_assessment_codes = codelist_from_csv(
    "codelists/opensafely-assessment-instruments-and-outcome-measures-for-long-covid.csv",
    column = "code"
)     
    
long_covid_dx_codes =  codelist_from_csv(
    "codelists/opensafely-nice-managing-the-long-term-effects-of-covid-19.csv",
    column = "code"
) 

long_covid_referral_codes = codelist_from_csv(
    "codelists/opensafely-referral-and-signposting-for-long-covid.csv",
    column = "code"
) 

# # Combine long covid codelists
lc_codelists_combined = (
    long_covid_dx_codes
    + long_covid_referral_codes
    + long_covid_assessment_codes
)

# 2. Ethnicities: 

ethnicity = codelist_from_csv(
    "codelists/opensafely-ethnicity.csv",
    column="Code",
)

# 3. Mental issues:
psychosis_schizophrenia_bipolar_codes = codelist_from_csv(
    "codelists/opensafely-psychosis-schizophrenia-bipolar-affective-disease.csv",
    column="CTV3Code",
)
depression_codes = codelist_from_csv(
    "codelists/opensafely-depression.csv", column="CTV3Code"
)
