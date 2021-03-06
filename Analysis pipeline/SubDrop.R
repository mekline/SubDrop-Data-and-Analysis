#Analysis of the SubjectDrop kid studies!

#setwd(mydir)

#Reading in all libraries that we (might) use
library(irr)
library(stringr)
library(languageR)
library(lme4)
library(multcomp)
library(binom)
library(dplyr)
library(lsr)
library(EMT)
library(ggplot2)
library(bootstrap)
library(pwr)
mean.na.rm <- function(x) { mean(x,na.rm=T) }
sum.na.rm <- function(x) { sum(x,na.rm=T) }
stderr <- function(x) sqrt(var(x)/length(x))
bootup <- function(mylist){
  foo <- bootstrap(mylist, 1000, mean)
  return(quantile(foo$thetastar, 0.975)[1])
}
bootdown <- function(mylist){
  foo <- bootstrap(mylist, 1000, mean)
  return(quantile(foo$thetastar, 0.025)[1])
}

#Get directory of this file
directory = getwd()

#Initialize dataset
subtable = data.frame(NULL)
#Load csv with Alldata into variable
subtable = read.csv(paste0(directory, "/SubDrop_reconciled.csv"), header = TRUE, stringsAsFactors = FALSE)


#Fix some badly formatted columns
subtable$Kid.Response.A...Prag.Choice. <- as.character (subtable$Kid.Response.A...Prag.Choice.)
subtable$Kid.Response.B...Prag.Choice. <- as.character (subtable$Kid.Response.B...Prag.Choice.)
subtable$Gender <- subtable$Gender..Guessed.from.Name.Appearance.

subtable[is.na(subtable)] <- 0

#Fix age calculations!
subtable$Age.Years <- as.numeric(as.character(subtable$Age.Years))
subtable$Days.Old <- as.numeric(as.character(subtable$Days.Old))

####################################
#Pick subset of data to analyze (experiment, kids included)

#Choose ParentSecret and ParentSecretControl study versions
subtable <- subtable[subtable$Experiment == "ParentSecret" | subtable$Experiment == "ParentSecretControl" | subtable$Experiment == "ParentSecretControl2" ,]
subtable[subtable$Experiment ==  "ParentSecretControl2",]$Experiment <- "ParentSecretControl"

#chose stricter inclusion criteria.., following new paradigm rules dropped <- subtable[subtable$Final.Include == 0,]
dropped <- subtable[subtable$Final.Include == 0,]

subtable <- subtable[subtable$Final.Include == 1,]

#who & why excluded from analysis?
table(dropped$Final.Reason, dropped$Experiment)
#Note: Bilingual, Developmental delay, no consent, too young/wrong age are outside the intended sample, tested bc it's the museum
#ExpErrorJ: A series of major implementation flaws were discovered after several months (:( ) - 1st RA implementation was very inconsistently implemented so a large # odf participants must be excluded)

#############################################
# Recode condition variables

#SD: 'subject drop' is the 'correct answer', other name for this condition is 'two fruits'
#OD: aka 'two animals'

#Note- we tried 2-trial (between-subj) and 4-trial (within-subj) versions of the task.  With within-subj 4-trial version, we saw big carryover effects during data collection. So, we only ever analyzed just 1st 2 trials
#from all versions togther.

subtable$oldCond <- subtable$Condition
subtable[subtable$Condition == "SDOD",]$Condition <- "SD"
subtable[subtable$Condition == "SDSD",]$Condition <- "SD"
subtable[subtable$Condition == "ODSD",]$Condition <- "OD"
subtable[subtable$Condition == "ODOD",]$Condition <- "OD"

## Code Correctness!  For main experiment, correctness = chose the pragmatic one; For cont, correctness = chose the correct one! (this is the same! wrong answers differ though)

subtable$isPragChoiceA <- "NA"
subtable[subtable$Condition == "SD" & subtable$Kid.Response.A...Prag.Choice. == "eat orange",]$isPragChoiceA <- 1
subtable[subtable$Condition == "OD" & subtable$Kid.Response.A...Prag.Choice. == "monkey eat",]$isPragChoiceA <- 1
subtable[subtable$Condition == "SD" & subtable$Kid.Response.A...Prag.Choice. == "monkey eat",]$isPragChoiceA <- 0
subtable[subtable$Condition == "OD" & subtable$Kid.Response.A...Prag.Choice. == "eat orange",]$isPragChoiceA <- 0
subtable[subtable$Condition == "SD" & subtable$Kid.Response.A...Prag.Choice. == "eat banana",]$isPragChoiceA <- 0
subtable[subtable$Condition == "OD" & subtable$Kid.Response.A...Prag.Choice. == "duck eat",]$isPragChoiceA <- 0

subtable$isPragChoiceB <- "NA"
subtable[subtable$Condition == "SD" & subtable$Kid.Response.B...Prag.Choice. == "pet dog",]$isPragChoiceB <- 1
subtable[subtable$Condition == "OD" & subtable$Kid.Response.B...Prag.Choice. == "girl pet",]$isPragChoiceB <- 1
subtable[subtable$Condition == "SD" & subtable$Kid.Response.B...Prag.Choice. == "girl pet",]$isPragChoiceB <- 0
subtable[subtable$Condition == "OD" & subtable$Kid.Response.B...Prag.Choice. == "pet dog",]$isPragChoiceB <- 0
subtable[subtable$Condition == "SD" & subtable$Kid.Response.B...Prag.Choice. == "pet cat",]$isPragChoiceB <- 0
subtable[subtable$Condition == "SD" & subtable$Kid.Response.B...Prag.Choice. == "pet kitty",]$isPragChoiceB <- 0 #lexical alternative!
subtable[subtable$Condition == "OD" & subtable$Kid.Response.B...Prag.Choice. == "boy pet",]$isPragChoiceB <- 0

#A few kis didn't answer on one trial and will need to be manually dropped
subtable <- subtable[subtable$isPragChoiceA != "NA",]
subtable <- subtable[subtable$isPragChoiceB != "NA",]
subtable$isPragChoiceA <- as.numeric(as.character(subtable$isPragChoiceA))
subtable$isPragChoiceB <- as.numeric(as.character(subtable$isPragChoiceB))



#Express this as # chose 'correct' across experiment
subtable$pragChoiceScore <- subtable$isPragChoiceA + subtable$isPragChoiceB

#...Or as # chose to drop the object
subtable$choseObjectDrop <- subtable$pragChoiceScore
subtable[subtable$Condition == "SD",]$choseObjectDrop <- 2-subtable[subtable$Condition == "SD",]$pragChoiceScore


####################################
#Descriptive stats for graphing (Developmental, small sample, so we'll present hist. of kids choosing each asnwer, rather than proportion scores)

#Time to split up the kids into Main and Control experiments 

maintable <- subtable[subtable$Experiment == "ParentSecret",] 
conttable <- subtable[subtable$Experiment == "ParentSecretControl" | subtable$Experiment == "ParentSecretControl2",] 

#Toss older/younger accidental participant from conttable, it's just for 3-4yos
conttable <- conttable[conttable$Age.Years < 5,]
conttable <- conttable[conttable$Age.Years > 2,]


#Look at n kids in sub-experiments (this is good for checking updates on n subjects needed per condition)
#How many kids of each Age, Experiment, Condition?

with(maintable, tapply(as.numeric(as.character(Final.Include)), list(Condition, Age.Years), sum.na.rm), drop=TRUE)
with(conttable, tapply(as.numeric(as.character(Final.Include)), list(Condition, Age.Years), sum.na.rm), drop=TRUE)

#Make sure factors are coded correctly, and melt the dataset for logistic analyses

maintable$Condition <- as.factor(maintable$Condition)
maintable$Subject <- as.factor(maintable$Subject..)
maintable$choseObjectDrop <- as.factor(maintable$choseObjectDrop)
maintable$pragChoice_1 <- maintable$isPragChoiceA
maintable$pragChoice_2 <- maintable$isPragChoiceB

#Get the objective coding scheme back :)
main.long = wideToLong(maintable,within="trial", sep='_')
main.long$choseObjectDrop <- main.long$pragChoice
main.long[main.long$Condition == "SD",]$choseObjectDrop <- 1-main.long[main.long$Condition == "SD",]$pragChoice

conttable$Condition <- as.factor(conttable$Condition)
conttable$Subject <- as.factor(conttable$Subject..)
conttable$choseObjectDrop <- as.factor(conttable$choseObjectDrop)
conttable$pragChoice_1 <- conttable$isPragChoiceA
conttable$pragChoice_2 <- conttable$isPragChoiceB

#Get the objective coding scheme back :)
cont.long = wideToLong(conttable,within="trial", sep='_')
cont.long$choseObjectDrop <- cont.long$pragChoice
cont.long[cont.long$Condition == "SD",]$choseObjectDrop <- 1-cont.long[cont.long$Condition == "SD",]$pragChoice

#For quick-and-dirty graphs
table(maintable$Condition, maintable$choseObjectDrop)
table(maintable$Age.Years, maintable$pragChoiceScore)

table(conttable$Condition, conttable$pragChoiceScore)
table(conttable$Age.Years, conttable$pragChoiceScore)



####################################
# Analysis!

###
# EXPERIMENT 2
###
#Question #1 - is choice of OD puppet sensitive to condition? (Figure 6)  ALL AGES, no age factor
# Logistic Regression model.  No (Condition|Subject) random effect because condition was varied between subjects
full_maximal_model <- glmer(choseObjectDrop ~ Condition + (Condition|trial) + (1|Subject), data=main.long, family="binomial")

#compare to model w/o fixed effect
no_fixed <- glmer(choseObjectDrop ~ 1 + (Condition|trial) + (1|Subject), data=main.long, family="binomial")
anova(full_maximal_model, no_fixed)

#Answer #1 marginal (p=0.09) (with all ages included)

###
#Question 2: Here we switch to 'pragmatic choice' bc subject & object order of speaking wasn't counterbalanced. Does age influence choice patterns?

#Scale age (z score), to avoid convergence problems 
main.long$Scaled.Days.Old <- scale(main.long$Days.Old)

# Logistic Regression model.  No (Condition|Subject) random effect because condition was varied between subjects
fullmax_age_model <- glmer(pragChoice ~ Scaled.Days.Old + (1|trial) + (1|Subject), data=main.long, family="binomial")

#Compare to a model without conditionxage interaction, and with same random effects structure as above
no_age <- glmer(pragChoice ~ 1 + (1|trial) + (1|Subject), data=main.long, family="binomial")
anova(fullmax_age_model, no_age)

#Answer #2: Yes!!
#Translation for the paper: for each year bin, did they tend to choose the 'correct' pragmatic choice? 
threes_m <- subset(maintable, Age.Years == 3)
fours_m <- subset(maintable, Age.Years == 4)
fives <- subset(maintable, Age.Years == 5)
sixes <- subset(maintable, Age.Years == 6)


multinomial.test(as.vector(table(threes_m$pragChoiceScore)),c(0.25, 0.5, 0.25))
multinomial.test(as.vector(table(fours_m$pragChoiceScore)),c(0.25, 0.5, 0.25))
multinomial.test(as.vector(table(fives$pragChoiceScore)),c(0.25, 0.5, 0.25))
multinomial.test(as.vector(table(sixes$pragChoiceScore)),c(0.25, 0.5, 0.25))

###
# 'Objective' task control; note that 'pragmatic' choice here actually means *correct* (vs incorrect) choice
# We collapse across Subject/Object question here since, again, no order counterbalancing, so there is just 1 'condition' to examine, age.  

#Question 1 (skip, no interpretable condition difference here)

#Question 2 (parallel above): Does age influence choice patterns?

#Scale age (z score), to avoid convergence problems 
cont.long$Scaled.Days.Old <- scale(cont.long$Days.Old)

# Logistic Regression model.  
full_max_cont_model <- glmer(pragChoice ~ Scaled.Days.Old + (1|trial) + (1|Subject), data=cont.long, family="binomial")
#Compare to a model without age interaction, and with same random effects structure as above
no_age_cont_model <- glmer(pragChoice ~ 1 + (1|trial) + (1|Subject), data=cont.long, family="binomial")
anova(full_max_cont_model, no_age_cont_model)

#Answer #2:We measure no significant difference!(but it wouldn't be crazy if there was one, p = 0.1)

#Translation for the paper: for each year bin, did they tend to choose the 'correct' pragmatic choice? Yes they do, but the 4s are numerically better than 3s on this task
threes_c <- subset(conttable, Age.Years == 3)
fours_c <- subset(conttable, Age.Years == 4)

multinomial.test(as.vector(table(threes_c$pragChoiceScore)),c(0.25, 0.5, 0.25))
multinomial.test(as.vector(table(fours_c$pragChoiceScore)),c(0.25, 0.5, 0.25))
conttab <- rbind(as.vector(table(fours_c$pragChoiceScore)), as.vector(table(threes_c$pragChoiceScore)))

fisher.test(threetab)

### Question #3 Do 3s and 4s differ in the two tasks? 
# We know: 3s and 4s both significantly above chance in cont task, only 4s above change in main; and only main task shows a continuous age effect
# But are the tasks actually different from one another by age?

#To answer, make a new dataset with both tasks and just the 3-4yos
main.long$Task <- 'main'
cont.long$Task <- 'cont'
threefour.long <- subset(rbind(main.long, cont.long), Age.Years < 5)

#full_max_three_model <- glmer(pragChoice ~ Task*Scaled.Days.Old + (Task|trial) + (1|Subject), data=threefour.long, family="binomial")
#noeff_three_model <- glmer(pragChoice ~ Task+Scaled.Days.Old + (Task|trial) + (1|Subject), data=threefour.long, family="binomial")
#that last doesn't converge! So test again with (1|trial)
nomax_three_model <- glmer(pragChoice ~ Task*Scaled.Days.Old + (1|trial) + (1|Subject), data=threefour.long, family="binomial")
nomaxnoeff_three_model <- glmer(pragChoice ~ Task+Scaled.Days.Old + (1|trial) + (1|Subject), data=threefour.long, family="binomial")

anova(nomax_three_model,nomaxnoeff_three_model) # comes out p=.3
#No task/age interaction!

#Trying the binned version:
threetab <- rbind(as.vector(table(threes_c$pragChoiceScore)), as.vector(table(threes_m$pragChoiceScore)))
fourtab <- rbind(as.vector(table(fours_c$pragChoiceScore)), as.vector(table(fours_m$pragChoiceScore)))

fisher.test(threetab)
fisher.test(fourtab)

#######
# GRAPHS
#######
all.long <- rbind(main.long, cont.long) %>%
  group_by(Subject, Age.Years, Experiment) %>%
  summarise(pragScore = sum(pragChoice)) %>%
  group_by(Age.Years, Experiment, pragScore) %>%
  summarise(pragNum = length(pragScore)) %>% #gosh this is easier, hooray for hadley!
  filter(Age.Years > 2) %>%
  filter(Age.Years < 7)

#Labels/formats for graphing
all.long$Age.Years <- factor(all.long$Age.Years, levels = unique(all.long$Age.Years))
all.long$pragScore <- factor(all.long$pragScore, levels = unique(all.long$pragScore))
all.long$ExpLabel = ""
all.long[all.long$Experiment == "ParentSecret",]$ExpLabel <- "Main experiment (helpful/unhelpful)"
all.long[all.long$Experiment == "ParentSecretControl",]$ExpLabel <- "Control (true/false)"
all.long$ExpLabel <- factor(all.long$ExpLabel, levels = c("Main experiment (helpful/unhelpful)", "Control (true/false)"))
all.long$PragLabel = ""
all.long[all.long$pragScore == 0,]$PragLabel <- 'n=0'
all.long[all.long$pragScore == 1,]$PragLabel <- 'n=1'
all.long[all.long$pragScore == 2,]$PragLabel <- 'n=2'
all.long$PragLabel <- factor(all.long$PragLabel, levels = c("n=0","n=1","n=2"))
library(RColorBrewer)
my.cols <- brewer.pal(7, "Oranges")
my.cols <- my.cols[c(2,4,6)]

ggplot(data=all.long, aes(x=Age.Years, y=pragNum, fill=PragLabel)) + 
  geom_bar(position=position_dodge(), stat="identity") +
  facet_grid(~ExpLabel, scale='free_x', space='free_x') +
  coord_cartesian(ylim=c(0,16)) +
  xlab('Age in years') +
  ylab('Number of children choosing n helpful/correct') +
  theme(legend.key = element_blank()) +
  theme_bw() +
  theme(strip.background = element_blank()) +
  scale_fill_manual(name="", values=my.cols) +
  theme(text = element_text(family="Times", size=rel(4))) +
  theme(legend.text = element_text(family="Times", size=rel(4))) +
  theme(axis.text = element_text(family="Times", size=rel(0.9))) +
  theme(strip.text = element_text(family="Times", size=rel(0.9)))


ggsave(filename="kid_subdrop.jpg", width=10, height=6)

#########
#Simpler graph for talks
main.long$Age.Years <- as.numeric(as.character(main.long$Age.Years))
main.long$Age.Months <- as.numeric(as.character(main.long$Age.Months))
graph.main.long <- main.long %>%
  group_by(Subject, Age.Years, Age.Months) %>%
  summarise(pragScore = mean(pragChoice)) %>%
  filter(Age.Years > 2) %>%
  filter(Age.Years < 7) %>%
  ungroup() %>%
  mutate(YearMonths = Age.Years*12 + Age.Months) %>%
  group_by(YearMonths)%>%
  summarise_at(c("pragScore"), funs(mean.na.rm, bootup, bootdown))


ggplot(data=graph.main.long, aes(x=YearMonths, y=mean.na.rm, fill=YearMonths)) + 
  geom_bar(position=position_dodge(), stat="identity") +
  geom_errorbar(aes(ymin=bootdown, ymax=bootup), colour="black", width=.1, position=position_dodge(.9)) +
  coord_cartesian(ylim=c(0,1)) +
  xlab('Age in years') +
  ylab('Percent helpful speakers chosen') +
  theme(legend.key = element_blank()) +
  theme_bw() +
  theme(strip.background = element_blank()) +
  theme(text = element_text(family="Times", size=rel(4))) +
  theme(legend.text = element_text(family="Times", size=rel(4))) +
  theme(axis.text = element_text(family="Times", size=rel(0.9))) +
  theme(strip.text = element_text(family="Times", size=rel(0.9)))

############
############

######Graphs


#Make a pretty dot graph I hope?
Scores <- aggregate(main.long$pragChoice, list(main.long$Subject), sum)
names(Scores) <- c("Subject","Score")
Ages <- main.long[ !duplicated(main.long$Subject), c("Subject","Days.Old")]

foo <- merge(Scores,Ages)

foo$JitScore <- jitter(foo$Score)

plot( foo$Days.Old, foo$JitScore)

#A final power analysis on the 3s?

#1) Assume they are at change for prag and at observed for t/f task. What is the nsubj needed to test for a difference with 1 trial

p1 = mean(subset(cont.long, Age.Years < 4)$pragChoice)

multi = c(p1^2, 2*p1*(1-p1), (1-p1)^2)
nullmulti = c(0.25,0.5,0.25)

w = sqrt(((multi[1]-nullmulti[1])^2)/nullmulti[1] + ((multi[2]-nullmulti[2])^2)/nullmulti[2] + ((multi[3]-nullmulti[3])^2)/nullmulti[3])

pwr.chisq.test(w = w,  sig.level = 0.05, power = 0.8, df=2)
