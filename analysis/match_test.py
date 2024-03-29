
import pandas as pd
from osmatching import match

match(
    case_csv="dataset_exp_lc_unmatched",
    match_csv="dataset_comparator_unmatched",
    matches_per_case= 5,
    match_variables={
        "age": 1,
        "sex": "category",
        "region": "category"
    },
    closest_match_variables=["age"],
    index_date_variable="index_date",
    replace_match_index_date_with_case="no_offset", 
    indicator_variable_name="exposure",
    date_exclusion_variables={
        "end_death": "before",
        "end_deregist": "before",
        "long_covid_dx_date": "before",
        "end_lc_cure": "before"
    },
    output_suffix="_stp",
    output_path="output",
)

# direct matching works on local machine