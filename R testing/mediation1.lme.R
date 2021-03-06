#' Simple Multilevel Mediation Model
#'
#' This function runs a complete simple mediation analysis with one
#' mediator, similiar to model 4 in PROCESS by A. Hayes (2013) using
#' the \code{lme} function from the \code{nlme} package for a multilevel
#' analysis.
#'
#' As part of the output, you will find data screening,
#' all three models used in the traditional Baron and
#' Kenny (1986) steps, total/direct/indirect effects, the z-score and p-value
#' for the Aroian Sobel test, and the bootstrapped confidence interval
#' for the indirect effect.
#'
#' @param y The dependent variable column name from your dataframe.
#' @param x The independent variable column name from your dataframe. This column
#' will be treated as X in mediation or moderation models, please see
#' diagrams online for examples.
#' @param m The mediator for your model, as this model only includes one mediator.
#' @param cvs The covariates you would like to include in the model.
#' Use a \code{c()} concatenated vector to use multiple covariates.
#' @param df The dataframe where the columns from the formula can be found.
#' Note that only the columns used in the analysis will be data screened.
#' @param with_out A logical value where you want to keep the outliers in
#' model \code{TRUE} or exclude them from the model \code{FALSE}.
#' @param nboot A numeric value indicating the number of bootstraps you would like to complete.
#' @param conf_level A numeric value indicating the confidence interval width for the boostrapped confidence interval.
#' @param random.lme A character vector indicating the random effects you wish to include in the model.
#' To use only random intercepts include: \code{"~1|INTERCEPT"} where INTERCEPT is a column name in the dataframe.
#' To use random intercepts and random slopes include: \code{"SLOPE|INTERCEPT"} where SLOPE is the column
#' name in the dataframe for the random slopes, and INTERCEPT is the column for the random intercepts.
#' If you wish to use multiple slopes or intercepts use \code{c()} to concatenate them together.
#' @param ... Other arguments that might be included for customizing your lme analysis.
#' If none are defined, the method argument will be set to ML for maximum likelihood, and na.action will
#' be set to na.omit.
#' @keywords mediation, regression, data screening, bootstrapping
#' @export
#' @examples
#' Dataset can be found on our OSF page and GitHub for this package.
#' mediation1.mlm()
#'
#' @export

mediation1.lme = function(y, x, m, cvs = NULL, df, with_out = T,
                      nboot = 1000, conf_level = .95, random.lme, ...) {

  require(boot); require(nlme)

  #stop if Y is categorical
  if (is.factor(df[ , y])){stop("Y should not be a categorical variable. Log regression options are coming soon.")}

  #stop if M is categorical
  if (is.factor(df[ , m])){stop("M should not be a categorial variable.")}

  #figure out if X is categorical
  if (is.factor(df[ , x])){xcat = TRUE} else {xcat = FALSE}

  #first create the full formula for data screening
  allformulas = createformula(y, x, m, cvs, type = "mediation1")

  #figure out other arguments
  other.args = list(...)
  if (is.null(other.args$na.action)){other.args$na.action = "na.omit"}
  if (is.null(other.args$method)){other.args$method = "ML"}


  #then do data screening
  screen = datascreen.lme(allformulas$eq3, df, with_out, random.lme, ...)

  #take out outlines and create finaldata
  if (with_out == F) { finaldata = subset(screen$fulldata, totalout < 2) } else { finaldata = screen$fulldata }

  model1 = lm(allformulas$eq1, data = finaldata) #c path
  model2 = lm(allformulas$eq2, data = finaldata) #a path
  model3 = lm(allformulas$eq3, data = finaldata) #b c' paths

  if (xcat == F){ #run this with continuous X
  #aroian sobel
  a = coef(model2)[x]
  b = coef(model3)[m]
  SEa = summary(model2)$coefficients[x,2]
  SEb = summary(model3)$coefficients[m,2]
  zscore = (a*b)/(sqrt((b^2*SEa^2)+(a^2*SEb^2)+(SEa*SEb)))
  pvalue = pnorm(abs(zscore), lower.tail = F)*2

  #reporting
  total = coef(model1)[x] #c path
  direct = coef(model3)[x] #c' path
  indirect = a*b

  } else {

    #figure out all the labels for X
    levelsx = paste(x, levels(df[, x])[-1], sep = "")
    total = NA; indirect = NA; direct = NA; zscore = NA; pvalue = NA

    #loop over that to figure out sobel and reporting
    for (i in 1:length(levelsx)){

      #aroian sobel
      a = coef(model2)[levelsx[i]]
      b = coef(model3)[m]
      SEa = summary(model2)$coefficients[levelsx[i],2]
      SEb = summary(model3)$coefficients[m,2]
      zscore[i] = (a*b)/(sqrt((b^2*SEa^2)+(a^2*SEb^2)+(SEa*SEb)))
      pvalue[i] = pnorm(abs(zscore[i]), lower.tail = F)*2

      #reporting
      total[i] = coef(model1)[levelsx[i]] #c path
      direct[i] = coef(model3)[levelsx[i]] #c' path
      indirect[i] = a*b

    } #close for loop
  } #close else x is categorical

  bootresults = boot(data = finaldata,
                     statistic = indirectmed,
                     formula2 = allformulas$eq2,
                     formula3 = allformulas$eq3,
                     x = x,
                     med.var = m,
                     R = nboot)

  if (xcat == F) { #run this if X is continuous
  bootci = boot.ci(bootresults,
                   conf = conf_level,
                   type = "norm")
  } else {
    bootci = list()
    for (i in 1:length(levelsx)){
      bootci[[i]] = boot.ci(bootresults,
                          conf = conf_level,
                          type = "norm",
                          index = i)
      names(bootci)[[i]] = levelsx[[i]]
    } #close for loop
  } #close else statement

  triangle = draw.med(model1, model2, model3, y, x, m, finaldata)

  return(list("datascreening" = screen,
              "model1" = model1,
              "model2" = model2,
              "model3" = model3,
              "total.effect" = total,
              "direct.effect" = direct,
              "indirect.effect" = indirect,
              "z.score" = zscore,
              "p.value" = pvalue,
              "boot.results" = bootresults,
              "boot.ci" = bootci,
              "diagram" = triangle
  ))
}

#' @rdname mediation1.mlm
#' @export
