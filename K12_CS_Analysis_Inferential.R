# Set working directory (so relative paths work)
setwd("C:/Users/User/Desktop/DataAnalysis") 

#Input the data with full match data (that has CDRC unmatched data)
data1 <- read.csv("combined_data_clean_final_full.csv")

#Import the library for data manipulation
library(dplyr)

#Extract only needed variables 
analysis_vars <- c(
  "CS_Classes_Offered", "school_enrollment",
  "SCHOOL_YEAR", "TitleI_Status",
  "Elementary", "Middle", "High",
  "Juvenile_Justice_School",
  "sex_female",
  "race_black", "race_hispanic", "race_asian",
  "race_multiracial", "race_american_indian"
)

#Missing data were handled using a combination of listwise deletion and imputation
nb_data <- data1 %>%
  filter(!is.na(CS_Classes_Offered)) %>%   # Keep only schools with observed CS enrollment
  filter(!is.na(school_enrollment)) %>%    # Keep only schools with known size
  filter(school_enrollment > 0) %>%        # Remove impossible values
  mutate(across(c(Elementary, Middle, High),
                ~ ifelse(is.na(.), 0, .)))

nb_data

#Export the data incase it is needed elsewhere
write.csv(
  nb_data,
  "nb_data_clean.csv",
  row.names = FALSE
)

#####Descriptive Statistics showing plot of the histogram of CS courses offered
library(ggplot2)

fig_cs_distribution <- ggplot(nb_data, aes(x = CS_Classes_Offered)) +
  geom_histogram(binwidth = 1, fill = "steelblue", color = "white") +
  facet_wrap(~ SCHOOL_YEAR) +
  coord_cartesian(xlim = c(0, 20)) +  # zoom in to make distribution visible
  labs(
    title = "Distribution of CS Classes Offered Across Schools by Year",
    x = "Number of CS Classes Offered",
    y = "Count of Schools"
  ) +
  theme_minimal()

fig_cs_distribution 

#Save the graph
ggsave(
 filename = "Figure1_CS_Distribution_by_Year.png",
  plot = fig_cs_distribution,
  width = 8,
  height = 6
)

##Inferential Statistics
#Import the library for or fitting and analyzing mixed-effects models
library(lme4)

#Check ICC (Intraclass Correlation Coefficient)
null_model <- lmer( CS_Classes_Offered ~ 1 + (1 | State_Code / District_ID), data = nb_data)
summary(null_model)

# Excels more than lme4 when dealing with zero-inflated data sets and speedy convergence is of essence
library(glmmTMB) 

library(splines) #The spline affects the relationship between school enrollment 
                #and the outcome, replacing a single linear term 
                #with a flexible curve that can change its effect 
                #across different enrollment levels.

#The standard negative binomial model assumes all schools are equally
#able to offer computer science courses, differing only in the number offered. 
access_model_m1 <- glmmTMB(
  CS_Classes_Offered ~ 
    SCHOOL_YEAR +
    TitleI_Status +
    Elementary + Middle + High +
    Juvenile_Justice_School +
    ns(log(school_enrollment), df = 2) +
    (1 | State_Code/District_ID),
  family = nbinom2,
  data = nb_data
)

summary (access_model_m1)

#In contrast, the zero-inflated model distinguishes between schools that 
#have no access to computer science at all and those that vary in the 
#number of courses offered, allowing for a more accurate representation of structural inequalities in access.
access_model_zi_m2 <- glmmTMB(
  CS_Classes_Offered ~ 
    SCHOOL_YEAR +
    TitleI_Status +
    Elementary + Middle + High +
    Juvenile_Justice_School +
    ns(log(school_enrollment), df = 2) +
    (1 | State_Code/District_ID),
  ziformula = ~1,
  family = nbinom2,
  data = nb_data
)

summary (access_model_zi_m2)

#Third model based on the assumption that zeros depend on institutional structure and size
access_model_zi_m3 <- glmmTMB(
  CS_Classes_Offered ~ SCHOOL_YEAR + TitleI_Status + Elementary + Middle + High +
    Juvenile_Justice_School + ns(log(school_enrollment), 2) +
    (1 | State_Code/District_ID),
  ziformula = ~ TitleI_Status + Elementary + Middle + log(school_enrollment),
  family = nbinom2,
  data = nb_data
)

summary (access_model_zi_m3)

#Run AIC comparison
AIC(access_model_m1, access_model_zi_m2, access_model_zi_m3)

#The added variables introduced more missingness
nb_data2 <- data1 %>%
  filter(school_enrollment > 0) %>%
  mutate(across(c(Elementary, Middle, High),
                ~ ifelse(is.na(.), 0, .))) %>%
  filter(complete.cases(across(all_of(analysis_vars))))


#Export the second data for possible use in the future
write.csv(
  nb_data2,
  "nb_data2_clean.csv",
  row.names = FALSE
)

##Models with more independent variables 
#Negative binomial
access_model_m1b <- glmmTMB(
  CS_Classes_Offered ~ 
    SCHOOL_YEAR +
    TitleI_Status +
    Elementary + Middle + High +
    Juvenile_Justice_School +
    
    ns(log(school_enrollment), df = 2) +
    
    # Gender composition (school-level, NOT CS-specific)
    sex_female +
    
    # Race composition (school-level, NOT CS-specific)
    race_black +
    race_hispanic +
    race_asian +
    race_multiracial +
    race_american_indian +
    
    (1 | State_Code/District_ID),
  
  family = nbinom2,
  data = nb_data2
)

summary(access_model_m1b)

#Zero-inflated negative binomial
access_model_zi_m2b <- glmmTMB(
  CS_Classes_Offered ~ 
    SCHOOL_YEAR +
    TitleI_Status +
    Elementary + Middle + High +
    Juvenile_Justice_School +
    
    ns(log(school_enrollment), df = 2) +
    
    sex_female +
    race_black +
    race_hispanic +
    race_asian +
    race_multiracial +
    race_american_indian +
    
    (1 | State_Code/District_ID),
  
  ziformula = ~1,
  family = nbinom2,
  data = nb_data2
)

summary(access_model_zi_m2b)

#Model added based on the assumption that structure impact zero CS course offering
access_model_zi_m3b <- glmmTMB(
  CS_Classes_Offered ~ 
    SCHOOL_YEAR +
    TitleI_Status +
    Elementary + Middle + High +
    Juvenile_Justice_School +
    
    ns(log(school_enrollment), df = 2) +
    
    sex_female +
    race_black +
    race_hispanic +
    race_asian +
    race_multiracial +
    race_american_indian +
    
    (1 | State_Code/District_ID),
  
  ziformula = ~ Elementary + Middle + TitleI_Status + log(school_enrollment),
  family = nbinom2,
  data = nb_data2
)

summary(access_model_zi_m3b)

#Run AIC comparison
AIC(access_model_m1b, access_model_zi_m2b, access_model_zi_m3b)

##Install the packages
#install.packages("performance")  
#install.packages("DHARMa")
#install.packages("see")
#install.packages("ggplot2") 

# Load the libraries
library(performance) #Model diagnostics (tests) 
library(DHARMa) #Model quality metrics
library(see) #Pretty diagnostic visuals
library(ggplot2) #General plots

# Create folders
dir.create("outputs/plots", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/tables", recursive = TRUE, showWarnings = FALSE)

# DHARMa diagnostics for the baseline model
sim_res_nb <- simulateResiduals(access_model_zi_m3)
plot(sim_res_nb)

testDispersion(sim_res_nb)
testZeroInflation(sim_res_nb)
testUniformity(sim_res_nb)

# Figure 1 — ZINB baseline residual diagnostics
png("outputs/plots/Figure1_DHARMa_ZINB_baseline.png",
    width = 1400, height = 1000, res = 150)

plot(sim_res_nb)

dev.off()

# DHARMa diagnostics for the extended model
sim_res_nb2 <- simulateResiduals(access_model_zi_m3b)
plot(sim_res_nb2)

testDispersion(sim_res_nb2)
testZeroInflation(sim_res_nb2)
testUniformity(sim_res_nb2)

# Figure 2 — ZINB extended residual diagnostics
png("outputs/plots/Figure2_DHARMa_ZINB_extended.png",
    width = 1400, height = 1000, res = 150)

plot(sim_res_nb2)

dev.off()

# Diagnostics for Collinearity (VIF-style check)
check_collinearity(access_model_zi_m3)
check_collinearity(access_model_zi_m3b)

# Table 1 & 2 — Collinearity (VIF)
capture.output(check_collinearity(access_model_zi_m3),
               file = "outputs/tables/Table1_VIF_baseline.txt")

capture.output(check_collinearity(access_model_zi_m3b),
               file = "outputs/tables/Table2_VIF_extended.txt")

# Random effect inspection for baseline model
re_base <- ranef(access_model_zi_m3)$cond

# Check grouping names
names(re_base)

# Replace the names (re_base) 

district_base <- data.frame(
  Group = "District",
  ID = rownames(re_base$District_ID),
  Effect = re_base$District_ID[,1]
)

state_base <- data.frame(
  Group = "State",
  ID = rownames(re_base$State_Code),
  Effect = re_base$State_Code[,1]
)

# Combine together
random_effects_base <- rbind(
  district_base,
  state_base
)

# Export
write.csv(
  random_effects_base,
  "outputs/tables/Table_RandomEffects_Baseline.csv",
  row.names = FALSE
)

#Random effect inspection for extended model
re_ext <- ranef(access_model_zi_m3b)$cond

# Check grouping names
names(re_ext)

# Replace names accordingly
district_ext <- data.frame(
  Group = "District",
  ID = rownames(re_ext$District_ID),
  Effect = re_ext$District_ID[,1]
)

state_ext <- data.frame(
  Group = "State",
  ID = rownames(re_ext$State_Code),
  Effect = re_ext$State_Code[,1]
)

# Combine together
random_effects_ext <- rbind(
  district_ext,
  state_ext
)

# Export
write.csv(
  random_effects_ext,
  "outputs/tables/Table_RandomEffects_Extended.csv",
  row.names = FALSE
)

# R-squared
r2_nakagawa(access_model_zi_m3)
r2_nakagawa(access_model_zi_m3b)

# Table 3 & 4 — R² results
capture.output(r2_nakagawa(access_model_zi_m3),
               file = "outputs/tables/Table3_R2_baseline.txt")

capture.output(r2_nakagawa(access_model_zi_m3b),
               file = "outputs/tables/Table4_R2_extended.txt")

# Predicted value checks for baseline model
pred_base <- predict(access_model_zi_m3, type = "response")
summary(pred_base)

# Figure 5 — Predicted vs observed (baseline)
png("outputs/plots/Figure5_Predicted_Baseline.png",
    width = 1400, height = 1000, res = 150)

plot(nb_data$CS_Classes_Offered, pred_base,
     xlab = "Observed CS Classes",
     ylab = "Predicted CS Classes",
     main = "Observed vs Predicted (Baseline Model)",
     pch = 16, col = "steelblue")

abline(0, 1, col = "red", lwd = 2)

dev.off()

# Predicted value checks for extended model
pred_ext <- predict(access_model_zi_m3b, type = "response")
summary(pred_ext)

# Figure 6 — Predicted vs observed (extended)
png("outputs/plots/Figure6_Predicted_Extended.png",
    width = 1400, height = 1000, res = 150)

plot(nb_data2$CS_Classes_Offered, pred_ext,
     xlab = "Observed CS Classes",
     ylab = "Predicted CS Classes",
     main = "Observed vs Predicted (Extended Model)",
     pch = 16, col = "steelblue")

abline(0, 1, col = "red", lwd = 2)

dev.off()

# Table 5 — predicted vs observed (baseline)
comparison_base <- data.frame(
  observed = nb_data$CS_Classes_Offered,
  predicted = pred_base
)

write.csv(comparison_base,
          "outputs/tables/pred_vs_actual_baseline.csv",
          row.names = FALSE)

# Table 6 — predicted vs observed (extended)
comparison_ext <- data.frame(
  observed = nb_data2$CS_Classes_Offered,
  predicted = pred_ext
)

write.csv(comparison_ext,
          "outputs/tables/pred_vs_actual_extended.csv",
          row.names = FALSE)

# Residual plot for baseline model
residuals_base <- nb_data$CS_Classes_Offered - pred_base

png("outputs/plots/Figure7_Residual_Baseline.png",
    width = 1400, height = 1000, res = 150)

plot(pred_base, residuals_base,
     xlab = "Predicted",
     ylab = "Residuals",
     main = "Residual Plot (Baseline Model)",
     pch = 16, col = "darkgray")

abline(h = 0, col = "red")

dev.off()

# Residual plot for extended model
residuals_ext <- nb_data2$CS_Classes_Offered - pred_ext

png("outputs/plots/Figure8_Residual_Extended.png",
    width = 1400, height = 1000, res = 150)

plot(pred_ext, residuals_ext,
     xlab = "Predicted",
     ylab = "Residuals",
     main = "Residual Plot (Extended Model)",
     pch = 16, col = "darkgray")

abline(h = 0, col = "red")

dev.off()

# Distribution plot of baseline model
png("outputs/plots/Figure9_Distribution_Baseline.png",
    width = 1400, height = 1000, res = 150)

hist(nb_data$CS_Classes_Offered,
     breaks = 50, col = rgb(0,0,1,0.5),
     main = "Observed vs Predicted",
     xlab = "CS Classes")

hist(pred_base,
     breaks = 50, col = rgb(1,0,0,0.5),
     add = TRUE)

legend("topright",
       legend = c("Observed", "Predicted"),
       fill = c(rgb(0,0,1,0.5), rgb(1,0,0,0.5)))

dev.off()

# Distribution plot of extended model
png("outputs/plots/Figure10_Distribution_Extended.png",
    width = 1400, height = 1000, res = 150)

hist(nb_data2$CS_Classes_Offered,
     breaks = 50, col = rgb(0,0,1,0.5),
     main = "Observed vs Predicted",
     xlab = "CS Classes")

hist(pred_ext,
     breaks = 50, col = rgb(1,0,0,0.5),
     add = TRUE)

legend("topright",
       legend = c("Observed", "Predicted"),
       fill = c(rgb(0,0,1,0.5), rgb(1,0,0,0.5)))

dev.off()


#Plot of the district level random effects
library(ggplot2)
Figure13_District_random_effect <- ggplot(district_base, aes(x = Effect)) +
  geom_histogram(bins = 50, fill = "steelblue", color = "white") +
  theme_minimal() +
  labs(
    title = "Distribution of District Random Effects",
    x = "District Random Intercept",
    y = "Count"
  )

# Save figure
ggsave(
  filename = "outputs/figures/Figure13_District_random_effect.png",
  plot = Figure13_District_random_effect,
  width = 8,
  height = 6,
  dpi = 300
)

# Extract state random effects
re_state <- ranef(access_model_zi_m3)$cond$State_Code

# Convert to data frame
state_effects <- data.frame(
  State = rownames(re_state),
  Effect = re_state[,1]
)

# Order by effect size
state_effects <- state_effects[
  order(state_effects$Effect),
]

# Convert State to ordered factor
state_effects$State <- factor(
  state_effects$State,
  levels = state_effects$State
)

# Plot
png(
  "outputs/plots/Figure_State_RandomEffects.png",
  width = 1400,
  height = 1000,
  res = 150
)

plot(
  state_effects$Effect,
  1:nrow(state_effects),
  yaxt = "n",
  pch = 19,
  col = "steelblue",
  xlab = "Random Effect Estimate",
  ylab = "State",
  main = "State-Level Random Effects"
)

axis(
  2,
  at = 1:nrow(state_effects),
  labels = state_effects$State,
  las = 1
)

abline(v = 0, col = "red", lwd = 2)

dev.off()
