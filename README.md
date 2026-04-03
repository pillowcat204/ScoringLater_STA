# ScoringLater_STA

This repository provides example R code and input files for a representative simulation condition from the study:

**The Impact of Scoring Polytomous Items Later Using the Shadow Test Approach**

The example demonstrates how scoring-later versus scoring-within conditions were implemented under the Shadow Test Approach (STA) in a mixed-format adaptive testing setting.

---

## Repository contents

- `R/cat_2.R`: simulation script for one representative condition  
- `R/calc_pairwise_overlaps.R`: helper function for pairwise overlap calculations  
- `data/irt.par.csv`: item parameter file  
- `data/itemattrib_1st.csv`: item attribute file (polytomous items located in the first half of the test)
- `data/constraints_2_SW.csv`: constraints for the scoring-within condition  
- `data/constraints_2_SL.csv`: constraints for the scoring-later condition  
- `output/`: folder for generated simulation results  

---

## Representative condition

This example corresponds to a condition with:

- test length = 20 items  
- test design = CAT  
- number of polytomous items = 2
- polytomous item location = first half of the test  

Two scoring scenarios are considered:

- **SW**: polytomous items were administered and scored at their designated positions during the test
- **SL**: polytomous items were administered but not scored during the test, their responses were incorporated only in final scoring. 

This condition is provided as an illustrative example of the simulation framework used in the study. Other conditions in the full study follow the same general structure with different design settings.

---

## Software requirements

The code was written in R and requires the following packages:

- TestDesign  
- Rsymphony  
- dplyr  
- catR  

---

## How to run

1. Clone or download this repository.  
2. Open R in the project directory.  
3. Install required packages if needed.  
4. Run:

```r
source("R/cat_2.R")
```

The script will generate an output file in the `output/` folder.

---

## Output

The script produces simulation results for 100 replications, including summary indices such as:

- RMSE
- mean bias
- pairwise test overlap  
- maximum item exposure rate  

---

## Data and code availability

The materials in this repository are provided to support transparency and reproducibility for a representative condition reported in the manuscript.
