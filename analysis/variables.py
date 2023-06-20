from datetime import date
from databuilder.ehrql import Dataset, days, case, when
from databuilder.tables.beta.tpp import (
    clinical_events,
    appointments,
    emergency_care_attendances,
    hospital_admissions,
    patients,
    practice_registrations,
    sgss_covid_all_tests,
    ons_deaths,
)
from ehrql.tables.beta.core import medications
from databuilder.codes import ICD10Code
from codelists import *
import operator
from functools import reduce

# temp zone for testing: -------
study_start_date = date(2020, 11, 1)
study_end_date = date(2023, 1, 31)
hx_study_end_date = date(2020, 3, 1)

age = (study_start_date - patients.date_of_birth).years
lc_dx = clinical_events.where(clinical_events.snomedct_code.is_in(lc_codelists_combined)) \
    .sort_by(clinical_events.date) \
    .first_for_patient()# had lc dx and dx dates
# -----

# Function codes for extracting monthly GP visit
def add_visits(dataset, from_date, num_months):
    # Number of GP visits within `num_months` of `from_date`
    num_visits = appointments \
        .where((appointments.start_date >= from_date) &
              (appointments.start_date <= (from_date + days(num_months * 30)))) \
        .count_for_patient()
    setattr(dataset, f"gp_visit_m{num_months}", num_visits)

# Function codes for cumulative historical GP visits: from 2020-1-31 backward calculating
def add_hx_gp_visits(dataset, num_months):
    # Number of GP visits within `num_months` of `from_date`
    num_visits = appointments \
        .where((appointments.start_date >= (hx_study_end_date - days(num_months * 30))) &
              (appointments.start_date <= hx_study_end_date)) \
        .count_for_patient()
    setattr(dataset, f"hx_gp_visit_m{num_months}", num_visits)


# # Function codes for hospitalisation visit counts：
# Q: if a person stayed in a hospital for more than one month, is it one adm? 
def add_hos_visits(dataset, from_date, num_months):
    # Number of Hospitalisation within `num_months` of `from_date`
    num_visits = hospital_admissions \
        .where((hospital_admissions.admission_date >= from_date) &
              (hospital_admissions.discharge_date  <= (from_date + days(num_months * 30)))) \
        .count_for_patient()
    setattr(dataset, f"hos_visit_m{num_months}", num_visits)

# Historical hospital visit
def add_hx_hos_visits(dataset, num_months):
    # Number of Hospitalisation within `num_months` of `from_date`
    num_visits = hospital_admissions \
        .where((hospital_admissions.admission_date >= (hx_study_end_date - days(num_months * 30))) &
              (hospital_admissions.discharge_date  <= hx_study_end_date)) \
        .count_for_patient()
    setattr(dataset, f"hx_hos_visit_m{num_months}", num_visits)


# # Function codes for A&E visit counts
def add_ae_visits(dataset, from_date, num_months):
    # Number of A&E visits within `num_months` of `from_date`
    num_visits = emergency_care_attendances \
        .where((emergency_care_attendances.arrival_date >= from_date) &
              (emergency_care_attendances.arrival_date  <= (from_date + days(num_months * 30)))) \
        .count_for_patient()
    setattr(dataset, f"ae_visit_m{num_months}", num_visits)

# Function codes for the historical A&E
def add_hx_ae_visits(dataset, num_months):
    # Number of A&E visits within `num_months` of `from_date`
    num_visits = emergency_care_attendances \
        .where((emergency_care_attendances.arrival_date >= (hx_study_end_date - days(num_months * 30))) &
              (emergency_care_attendances.arrival_date  <= hx_study_end_date)) \
        .count_for_patient()
    setattr(dataset, f"hx_ae_visit_m{num_months}", num_visits)



# Function codes for extracting hospitalisation records
def any_of(conditions):
    return reduce(operator.or_, conditions)

def hospitalisation_diagnosis_matches(admissions, codelist):
  code_strings = set()
  for code in codelist:
    # Pass the string through the ICD10Code to constructor to validate that it has
    # the expected format
    code_string = ICD10Code(code)._to_primitive_type()
    code_strings.add(code_string)
  conditions = [
    # The reason a plain substring search like this works is twofold:
    #
    # * ICD-10 codes all start with the sequence [A-Z][0-9] and do not contain
    #   such a sequence in any other part of the code. In this sense they are
    #   suffix-free and two codes will only match at they start if they match at
    #   all.
        # * Although the codes are not prefix-free they are organised hierarchically
    #   such that code A0123 represents a child concept of code A01. So although
    #   the naive substring matching below will find code A01 if code A0123 is
    #   present, this happens to be the behaviour we actually want.
    # Obviously this is all far from ideal though, and later we hope to be able
    # to pull these codes out in a separate table and handle the matching
    # properly.
    admissions.all_diagnoses.contains(code_string)
    for code_string in code_strings
  ]
  return admissions.where(any_of(conditions))


# Function for extracting clinical factors
def clinical_ctv3_matches(gpevent, codelist):
    gp_dx = (gpevent.where((gpevent.date < study_start_date) & gpevent.ctv3_code.is_in(codelist))
      .sort_by(gpevent.date).last_for_patient()
    )
    return gp_dx


# Create sequential variables for COVID-19 vaccine
def create_sequential_variables(
    dataset, variable_name_template, events, column, num_variables, sort_column=None
):
    sort_column = sort_column or column
    for index in range(num_variables):
        next_event = events.sort_by(getattr(events, sort_column)).first_for_patient()
        events = events.where(
            getattr(events, sort_column) > getattr(next_event, sort_column)
        )
        variable_name = variable_name_template.format(n=index + 1)
        setattr(dataset, variable_name, getattr(next_event, column))





# Function for adding medication number:
def drug_1gi_number(dataset, from_date, num_months):
    # Number of prescriptions within `num_months` of `from_date`
    num_pres = medications \
        .where((medications.date >= from_date) &
              (medications.date  <= (from_date + days(num_months * 30)))) \
        .where(medications.dmd_code.is_in(drug_bnf_ch1_gi_dmd)).count_for_patient()
    setattr(dataset, f"gi_drug_{num_months}", num_pres)

def drug_2cv_number(dataset, from_date, num_months):
    # Number of prescriptions within `num_months` of `from_date`
    num_pres = medications \
        .where((medications.date >= from_date) &
              (medications.date  <= (from_date + days(num_months * 30)))) \
        .where(medications.dmd_code.is_in(drug_bnf_ch2_cv_dmd)).count_for_patient()
    setattr(dataset, f"cv_drug_{num_months}", num_pres)


def drug_3chest_number(dataset, from_date, num_months):
    # Number of prescriptions within `num_months` of `from_date`
    num_pres = medications \
        .where((medications.date >= from_date) &
              (medications.date  <= (from_date + days(num_months * 30)))) \
        .where(medications.dmd_code.is_in(drug_bnf_ch3_chest_dmd)).count_for_patient()
    setattr(dataset, f"chest_drug_{num_months}", num_pres)


def drug_4cns_number(dataset, from_date, num_months):
    # Number of prescriptions within `num_months` of `from_date`
    num_pres = medications \
        .where((medications.date >= from_date) &
              (medications.date  <= (from_date + days(num_months * 30)))) \
        .where(medications.dmd_code.is_in(drug_bnf_ch4_cns_dmd)).count_for_patient()
    setattr(dataset, f"cns_drug_{num_months}", num_pres)


def drug_5inf_number(dataset, from_date, num_months):
    # Number of prescriptions within `num_months` of `from_date`
    num_pres = medications \
        .where((medications.date >= from_date) &
              (medications.date  <= (from_date + days(num_months * 30)))) \
        .where(medications.dmd_code.is_in(drug_bnf_ch5_inf_dmd)).count_for_patient()
    setattr(dataset, f"inf_drug_{num_months}", num_pres)


def drug_6meta_number(dataset, from_date, num_months):
    # Number of prescriptions within `num_months` of `from_date`
    num_pres = medications \
        .where((medications.date >= from_date) &
              (medications.date  <= (from_date + days(num_months * 30)))) \
        .where(medications.dmd_code.is_in(drug_bnf_ch6_meta_dmd)).count_for_patient()
    setattr(dataset, f"meta_drug_{num_months}", num_pres)

def drug_7gyn_number(dataset, from_date, num_months):
    # Number of prescriptions within `num_months` of `from_date`
    num_pres = medications \
        .where((medications.date >= from_date) &
              (medications.date  <= (from_date + days(num_months * 30)))) \
        .where(medications.dmd_code.is_in(drug_bnf_ch7_gyn)).count_for_patient()
    setattr(dataset, f"gyn_drug_{num_months}", num_pres)


def drug_8cancer_number(dataset, from_date, num_months):
    # Number of prescriptions within `num_months` of `from_date`
    num_pres = medications \
        .where((medications.date >= from_date) &
              (medications.date  <= (from_date + days(num_months * 30)))) \
        .where(medications.dmd_code.is_in(drug_bnf_ch8_cancer_dmd)).count_for_patient()
    setattr(dataset, f"cancer_drug_{num_months}", num_pres)


def drug_9diet_number(dataset, from_date, num_months):
    # Number of prescriptions within `num_months` of `from_date`
    num_pres = medications \
        .where((medications.date >= from_date) &
              (medications.date  <= (from_date + days(num_months * 30)))) \
        .where(medications.dmd_code.is_in(drug_bnf_ch9_diet_blood_dmd)).count_for_patient()
    setattr(dataset, f"diet_drug_{num_months}", num_pres)


def drug_10muscle_number(dataset, from_date, num_months):
    # Number of prescriptions within `num_months` of `from_date`
    num_pres = medications \
        .where((medications.date >= from_date) &
              (medications.date  <= (from_date + days(num_months * 30)))) \
        .where(medications.dmd_code.is_in(drug_bnf_ch10_muscle_dmd)).count_for_patient()
    setattr(dataset, f"muscle_drug_{num_months}", num_pres)


def drug_11eye_number(dataset, from_date, num_months):
    # Number of prescriptions within `num_months` of `from_date`
    num_pres = medications \
        .where((medications.date >= from_date) &
              (medications.date  <= (from_date + days(num_months * 30)))) \
        .where(medications.dmd_code.is_in(drug_bnf_ch11_eye_dmd)).count_for_patient()
    setattr(dataset, f"eye_drug_{num_months}", num_pres)


def drug_12ent_number(dataset, from_date, num_months):
    # Number of prescriptions within `num_months` of `from_date`
    num_pres = medications \
        .where((medications.date >= from_date) &
              (medications.date  <= (from_date + days(num_months * 30)))) \
        .where(medications.dmd_code.is_in(drug_bnf_ch12_ent_dmd)).count_for_patient()
    setattr(dataset, f"ent_drug_{num_months}", num_pres)


def drug_13skin_number(dataset, from_date, num_months):
    # Number of prescriptions within `num_months` of `from_date`
    num_pres = medications \
        .where((medications.date >= from_date) &
              (medications.date  <= (from_date + days(num_months * 30)))) \
        .where(medications.dmd_code.is_in(drug_bnf_ch13_skin_dmd)).count_for_patient()
    setattr(dataset, f"skin_drug_{num_months}", num_pres)


# Temp: test generate data
# dataset = Dataset()
# dataset.define_population(age >= 18)

# drug_12ent_number(dataset, lc_dx.date, num_months=2)
# add_visits(dataset, lc_dx.date, num_months=1)
# add_visits(dataset, lc_dx.date, num_months=2)
# add_hos_visits(dataset, lc_dx.date, num_months=3)
# add_hos_visits(dataset, lc_dx.date, num_months=4)
# add_ae_visits(dataset, lc_dx.date, num_months=5)
# add_ae_visits(dataset, lc_dx.date, num_months=6)