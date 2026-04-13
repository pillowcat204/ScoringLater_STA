############################   R/cat_2.R   ############################

# Load required packages
library(TestDesign)
library(Rsymphony)
library(dplyr)
library(catR)

# Source helper function
source("code/calc_pairwise_overlaps.R")

# ------------------------------------------------------------------------------
# Representative condition
# - test length = 20
# - test design = CAT
# - number of polytomous items = 2
# - polytomous item location = first half of the test
# - scoring scenarios: SW (scoring within) and SL (scoring later)
# ------------------------------------------------------------------------------

test.length <- 20
test.poly <- 2
test.dich <- test.length - test.poly
theta_cut <- -0.67
n_rep <- 100
sample_size <- 1000

# Create output folder if needed
if (!dir.exists("output")) {
  dir.create("output", recursive = TRUE)
}

# Load item parameter file
itempool_data <- read.csv("data/irt.par.csv")[, -1]
itempool_data <- itempool_data[, c(6, 1:5)]
colnames(itempool_data)[1] <- "ID"

# Load item attribute file
itemattrib_data <- read.csv("data/itemattrib_1st.csv")

# Load item pool and attributes
itempool <- loadItemPool(itempool_data)
itemattrib <- loadItemAttrib(itemattrib_data, itempool)

# Load constraints
constraints_data_SW <- read.csv("data/constraints_2_SW.csv")
constraints_data_SL <- read.csv("data/constraints_2_SL.csv")

constraints_SW <- loadConstraints(constraints_data_SW, itempool, itemattrib)
constraints_SL <- loadConstraints(constraints_data_SL, itempool, itemattrib)

# Shadow-test configuration
cfg_adaptive <- createShadowTestConfig(
  MIP = list(solver = "Rsymphony"),
  refresh_policy = list(
    method = "ALWAYS"
  ),
  exposure_control = list(
    method = "ELIGIBILITY",
    max_exposure_rate = rep(0.25, 10),
    n_segment = 10,
    segment_cut = c(-Inf, seq(-4, 4, 1), Inf)
  )
) # default interim_theta/final_theta estimator = EAP

# Generate population
set.seed(1)
true_theta_pop <- matrix(rnorm(n = 36000, mean = 0, sd = 1), ncol = 1)

all_results <- vector("list", n_rep)

for (rep in seq_len(n_rep)) {
  set.seed(rep)
  
  # Sample examinees from the population
  theta <- matrix(
    true_theta_pop[sample(nrow(true_theta_pop), sample_size), ],
    ncol = 1
  )
  
  # Run STA under scoring-within and scoring-later conditions
  adaptive_SW <- Shadow(cfg_adaptive, constraints_SW, true_theta = theta)
  adaptive_SL <- Shadow(cfg_adaptive, constraints_SL, true_theta = theta)
  
  # ---------------------------------------------------------------------------
  # SW: polytomous items are administered and scored during the test
  # ---------------------------------------------------------------------------
  test_list_SW <- vector("list", sample_size)
  poly_dat_list <- vector("list", sample_size)
  item_index_SW <- vector("list", sample_size)
  theta_est_SW <- numeric(sample_size)
  se_est_SW <- numeric(sample_size)
  theta_catR_SW <- numeric(sample_size)
  
  for (i in seq_len(sample_size)) {
    theta_est_SW[i] <- adaptive_SW@output[[i]]@final_theta_est
    se_est_SW[i] <- adaptive_SW@output[[i]]@final_se_est
    
    index <- adaptive_SW@output[[i]]@administered_item_index
    response <- adaptive_SW@output[[i]]@administered_item_resp
    ncat <- adaptive_SW@output[[i]]@administered_item_ncat
    
    item_index_SW[[i]] <- index
    
    test_i <- itempool_data[index, ]
    test_list_SW[[i]] <- test_i
    
    combined_matrix <- rbind(index, response, ncat)
    combined_df <- as.data.frame(combined_matrix)
    item_ID <- test_i[["ID"]]
    colnames(combined_df) <- item_ID
    
    # Keep the administered polytomous items for use in final SL scoring
    is_poly <- combined_df[3, ] == 3
    poly_dat_list[[i]] <- combined_df[, is_poly, drop = FALSE]
    
    it <- test_i[, 3:6]
    x <- response
    theta_catR_SW[i] <- thetaEst(it, x, model = "GRM", method = "EAP")
  }
  
  # ---------------------------------------------------------------------------
  # SL: polytomous items are not scored during routing;
  # their responses are added back only in final scoring
  # ---------------------------------------------------------------------------
  test_list_SL <- vector("list", sample_size)
  item_index_SL <- vector("list", sample_size)
  theta_est_SL <- numeric(sample_size)
  se_est_SL <- numeric(sample_size)
  theta_catR_SL <- numeric(sample_size)
  
  for (i in seq_len(sample_size)) {
    theta_est_SL[i] <- adaptive_SL@output[[i]]@final_theta_est
    se_est_SL[i] <- adaptive_SL@output[[i]]@final_se_est
    
    index <- adaptive_SL@output[[i]]@administered_item_index
    response <- adaptive_SL@output[[i]]@administered_item_resp
    ncat <- adaptive_SL@output[[i]]@administered_item_ncat
    
    # Add back the withheld polytomous item responses for final scoring
    index_final <- c(index, as.numeric(poly_dat_list[[i]][1, ]))
    response_final <- c(response, as.numeric(poly_dat_list[[i]][2, ]))
    ncat_final <- c(ncat, as.numeric(poly_dat_list[[i]][3, ]))
    
    item_index_SL[[i]] <- index_final
    
    test_i_final <- itempool_data[index_final, ]
    test_list_SL[[i]] <- test_i_final
    
    it <- test_i_final[, 3:6]
    x <- response_final
    theta_catR_SL[i] <- thetaEst(it, x, model = "GRM", method = "EAP")
  }
  
  # ---------------------------------------------------------------------------
  # Person-level results
  # ---------------------------------------------------------------------------
  test_results <- data.frame(
    true_theta = as.numeric(theta),
    SW_theta = theta_est_SW,
    SL_theta = theta_est_SL,
    SW_theta_catR = theta_catR_SW,
    SL_theta_catR = theta_catR_SL
  )
  
  test_results$bias_SW <- test_results$true_theta - test_results$SW_theta
  test_results$bias_SL <- test_results$true_theta - test_results$SL_theta
  test_results$bias_SW_catR <- test_results$true_theta - test_results$SW_theta_catR
  test_results$bias_SL_catR <- test_results$true_theta - test_results$SL_theta_catR
  
  test_results$squared_error_SW <- test_results$bias_SW^2
  test_results$squared_error_SL <- test_results$bias_SL^2
  test_results$squared_error_SW_catR <- test_results$bias_SW_catR^2
  test_results$squared_error_SL_catR <- test_results$bias_SL_catR^2
  
  # Pairwise overlap
  overlap_SW <- calc_pairwise_overlaps(item_index_SW)
  overlap_SL <- calc_pairwise_overlaps(item_index_SL)
  
  # Maximum exposure rate
  index_SW_vec <- as.vector(as.matrix(do.call(rbind, item_index_SW)))
  value_counts_SW <- table(index_SW_vec)
  max_exp_rate_SW <- max(value_counts_SW) / sample_size
  
  index_SL_vec <- as.vector(as.matrix(do.call(rbind, item_index_SL)))
  value_counts_SL <- table(index_SL_vec)
  max_exp_rate_SL <- max(value_counts_SL) / sample_size
  
  # Replication summary
  all_results[[rep]] <- data.frame(
    mean_bias_SW_shadow = mean(test_results$bias_SW),
    mean_bias_SL_shadow = mean(test_results$bias_SL),
    mean_bias_SW = mean(test_results$bias_SW_catR),
    mean_bias_SL = mean(test_results$bias_SL_catR),
    RMSE_SW_shadow = sqrt(mean(test_results$squared_error_SW)),
    RMSE_SL_shadow = sqrt(mean(test_results$squared_error_SL)),
    RMSE_SW = sqrt(mean(test_results$squared_error_SW_catR)),
    RMSE_SL = sqrt(mean(test_results$squared_error_SL_catR)),
    mean_overlap_SW = mean(overlap_SW$overlap),
    sd_overlap_SW = sd(overlap_SW$overlap),
    mean_overlap_SL = mean(overlap_SL$overlap),
    sd_overlap_SL = sd(overlap_SL$overlap),
    max_exp_SW = max_exp_rate_SW,
    max_exp_SL = max_exp_rate_SL,
    replication = rep
  )
}

# Combine all replications
final_results <- do.call(rbind, all_results)

# Check results
print(final_results)

# Save output
write.csv(final_results, "output/cat_2_results.csv", row.names = FALSE)
