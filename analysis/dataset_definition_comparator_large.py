from datetime import date

from databuilder.ehrql import Dataset, days, years
from databuilder.tables.beta.tpp import (
    patients, addresses, 
    practice_registrations, clinical_events,
    sgss_covid_all_tests,
)
from codelists import lc_codelists_combined

index_date = date(2020, 11, 1)
age = (index_date - patients.date_of_birth).years

# IMD
# # 1. drop the start date records after index date
# # 2. sort the date, keep the latest

index_date_address = addresses.drop(addresses.start_date > index_date) \
    .sort_by(addresses.start_date) \
    .last_for_patient()

# current registration
registration = practice_registrations \
    .drop(practice_registrations.start_date > index_date - years(1)) \
    .drop(practice_registrations.end_date <= index_date) \
    .sort_by(practice_registrations.start_date).last_for_patient()

# historical registration
historical_registration = practice_registrations \
    .drop(practice_registrations.start_date > date(2018, 11, 1)) \
    .drop(practice_registrations.end_date < date(2019, 11, 1))

# covid tests
latest_test_before_diagnosis = sgss_covid_all_tests \
    .take(sgss_covid_all_tests.is_positive) \
    .sort_by(sgss_covid_all_tests.specimen_taken_date).last_for_patient()

dataset = Dataset()
dataset.set_population((age >= 18) & registration.exists_for_patient())
dataset.age = age
dataset.sex = patients.sex
dataset.imd = index_date_address.imd_rounded
dataset.urban_rural_classification = index_date_address.rural_urban_classification 
dataset.region = registration.practice_stp
dataset.gp_practice = registration.practice_pseudo_id
dataset.registration_date = registration.start_date
dataset.historical_comparison_group = historical_registration.exists_for_patient()
dataset.comp_positive_covid_test = latest_test_before_diagnosis.exists_for_patient()
dataset.date_of_latest_positive_test_before_diagnosis = latest_test_before_diagnosis.specimen_taken_date
