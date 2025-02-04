################################################################################
# Coronavirus cross-protection
# Author: Naomi R Waterlow
# Date: 2021-04-08
################################################################################

# Analyse the traces and create figures for paper. 

######## LOAD THE TRACES ######
n_chains <- 16

# load the traces
load(here("fitting_seasonal/analysis","SEIR_PT_newlims5_5_2021-02-28.Rdata"))
trace_1_all <- total_trace
trace_temp <- lapply(total_trace[1:n_chains], function(i) label_trace(i))
timesteps <- 1:dim(total_trace[[1]])[1]
trace_1 <- lapply(trace_temp, function(i) format_trace(i, thin=, burnin=12000,
                                                       keep_all = F))

load(here("fitting_seasonal/analysis","SEIR_AWS_trace_2.Rdata"))
trace_2_all <- trace_to_save
trace_temp <- lapply(trace_to_save[1:n_chains], function(i) label_trace(i))
timesteps <- 1:dim(trace_temp[[1]])[1]
trace_2 <- lapply(trace_temp, function(i) format_trace(i, thin=, burnin=12000,
                                                       keep_all = F))

######### CONVERGENCE DIAGNOSTIC #######

compare_mcmc<-mcmc.list(mcmc(trace_1[[1]][1:45000,2:9]), 
                        mcmc(trace_2[[1]][1:45000,2:9]))

gelman_rubin <-gelman.diag(compare_mcmc)

print(paste0("The Gelman Rubin statistic is ", gelman_rubin[2]))

####### PLOT ONE MULTI-TRACE ######

trace_temps <- trace_1_all[[length(trace_1_all)-2]]
temperatures <- 1/trace_temps[dim(trace_temps)[1],]
timesteps <- c(1:dim(trace_1[[1]])[1])
# thinning 0 here as already thnned above
trace_edited <- lapply(trace_1, function(i) format_trace(i, thin=1, burnin=1, keep_all = T))
trace_edited <- Map(cbind, trace_1, temp = temperatures)

trace_combined <- do.call(rbind.data.frame, trace_edited)
trace_combined <- melt(trace_combined, id=c("time_steps", "temp"))

TRACE_PLOTS <- plot_trace(trace_combined)
DENS_PLOTS <- plot_density(trace_combined)

tiff(here("figures","Multi_trace_plot.tiff"), height = 2000, width = 3200, res = 300)

TRACE_PLOTS

dev.off()

####### COMBINE TRACES ####### (and save)

trace_to_sample <- rbind(trace_1[[1]][], trace_2[[1]])
save(trace_to_sample, file = here("fitting_seasonal/analysis","trace_to_sample.Rdata"))

####### PLOT POSTERIOR ######
trace_using <- data.table(trace_to_sample)

trace_using[,step:= 1:dim(trace_using)[1]]
ggtrace <- melt.data.table(trace_using, id.vars= c("step"))
colnames(ggtrace) <- c("step", "parameter", "value")
ggtrace <- ggtrace[parameter != "time_steps"]

tiff(here("figures","posterior.tiff"), height = 2000, width = 3200, res = 300)

ggplot(ggtrace) + 
  geom_density(aes(x = value)) + 
  facet_wrap(parameter~., scales = "free") + 
  theme_linedraw() + 
  theme(axis.text.y = element_blank(), 
        axis.ticks.y = element_blank()) + 
  labs(x = "Parameter value", y = "Density")

dev.off()

ggtrace_sub <- ggtrace[parameter == "waning_duration" | 
                         parameter == "seasonal_R0" | parameter == "log_liklihood"]
ggtrace_sub[parameter == "waning_duration", value := value/364]
ggtrace_sub[parameter == "waning_duration", parameter := "Waning duration (years)"]
ggtrace_sub[parameter == "seasonal_R0", parameter := "Seasonal HCoV R0"]
ggtrace_sub[parameter == "log_liklihood", parameter := "Log Posterior"]

SUB_POSTERIOR <-ggplot(ggtrace_sub) + 
  geom_density(aes(x = value), fill = "navyblue") + 
  facet_wrap(parameter~., scales = "free", ncol = 1) + 
  theme_linedraw() + 
  theme(axis.text.y = element_blank(), 
        axis.ticks.y = element_blank(),
        strip.background = element_rect(colour="white", fill="white"),
        strip.text = element_text(colour = 'black',hjust = 0)) + 
  labs(x = "Parameter value", y = "Density", title = "B")  + 
  theme(plot.margin = margin(t = 0.5, b = 0.5,r = 0.5, unit = "cm"))


######## RBINOM SAMPLING ######

RBINOM <- plot_rbinom(samples = 100, 
                      trace_period = c(1:dim(trace_to_sample)[1]),
                      trace_dt = trace_to_sample,
                      model_type = "SEIR")
RBINOM + labs(title = "A")

tiff(here("figures","rbinom.tiff"), height = 2000, width = 3200, res = 300)
grid.arrange(RBINOM+ labs(title = "A"), SUB_POSTERIOR, ncol = 2, widths = c(6,3))
dev.off()

######## QUANTILES ########
print("waning quantiles")
print(quantile(trace_to_sample$waning_duration, probs = c(0.025, 0.5, 0.975))/364)
print("R0 quantiles")
print(quantile(trace_to_sample$seasonal_R0, probs = c(0.025, 0.5, 0.975)))
print("reporting 1 quantiles")
print(quantile(trace_to_sample$reporting_rate_1, probs = c(0.025, 0.5, 0.975)))
print("reporting 2 quantiles")
print(quantile(trace_to_sample$reporting_rate_2, probs = c(0.025, 0.5, 0.975)))
print("reporting 3 quantiles")
print(quantile(trace_to_sample$reporting_rate_3, probs = c(0.025, 0.5, 0.975)))
print("reporting 4 quantiles")
print(quantile(trace_to_sample$reporting_rate_4, probs = c(0.025, 0.5, 0.975)))
print("seasonal amplitude quantiles")
print(quantile(trace_to_sample$seasonal_amplitude, probs = c(0.025, 0.5, 0.975)))
print("seasonal timing quantiles")
print(quantile(trace_to_sample$seasonal_timing, probs = c(0.025, 0.5, 0.975)))

# percentage change in amplitude

print(paste0("amplitude as proportion of R0 is ",
             unname(quantile(trace_to_sample$seasonal_amplitude, probs = 0.5)/ 
               quantile(trace_to_sample$seasonal_R0, probs = 0.5))
             )
      )

# Annual attack rate
 attack_rate(100, trace_period = 1:nrow(trace_to_sample), trace_dt = trace_to_sample, model_type = "SEIR")
