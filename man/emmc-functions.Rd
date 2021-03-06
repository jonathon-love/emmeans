% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/emm-contr.R
\name{contrast-methods}
\alias{contrast-methods}
\alias{pairwise.emmc}
\alias{emmc-functions}
\alias{revpairwise.emmc}
\alias{tukey.emmc}
\alias{poly.emmc}
\alias{trt.vs.ctrl.emmc}
\alias{trt.vs.ctrl1.emmc}
\alias{trt.vs.ctrlk.emmc}
\alias{dunnett.emmc}
\alias{eff.emmc}
\alias{del.eff.emmc}
\alias{consec.emmc}
\alias{mean_chg.emmc}
\title{Contrast families}
\usage{
pairwise.emmc(levs, ...)

revpairwise.emmc(levs, ...)

tukey.emmc(levs, reverse = FALSE)

poly.emmc(levs, max.degree = min(6, k - 1))

trt.vs.ctrl.emmc(levs, ref = 1)

trt.vs.ctrl1.emmc(levs, ...)

trt.vs.ctrlk.emmc(levs, ...)

dunnett.emmc(levs, ref = 1)

eff.emmc(levs, ...)

del.eff.emmc(levs, ...)

consec.emmc(levs, reverse = FALSE, ...)

mean_chg.emmc(levs, reverse = FALSE, ...)
}
\arguments{
\item{levs}{Vector of factor levels}

\item{...}{Additional arguments (these are ignored, but needed to make these functions 
  interchangeable)
Each contrast family has a default multiple-testing adjustment as noted
below. These adjustments are often only approximate; for a more exacting
adjustment, use the interfaces provided to \code{\link[multcomp]{glht}}
in the \pkg{multcomp} package.

\code{pairwise.emmc}, \code{revpairwise.emmc}, and \code{tukey.emmc} generate
contrasts for all pairwise comparisons among least-squares means at the
levels in levs. The distinction is in which direction they are subtracted.
For factor levels A, B, C, D, \code{pairwise.emmc} generates the comparisons
A-B, A-C, A-D, B-C, B-D, and C-D, whereas \code{revpairwise.emmc} generates
B-A, C-A, C-B, D-A, D-B, and D-C. \code{tukey.emmc} invokes
\code{pairwise.emmc} or \code{revpairwise.emmc} depending on \code{reverse}. 
The default multiplicity adjustment method is \code{"tukey"}, which is only
approximate when the standard errors differ.

\code{poly.emmc} generates orthogonal polynomial contrasts, assuming 
equally-spaced factor levels. These are derived from the
\code{\link[stats]{poly}} function, but an \emph{ad hoc} algorithm is used to
scale them to integer coefficients that are (usually) the same as in
published tables of orthogonal polynomial contrasts. The default multiplicity
adjustment method is \code{"none"}.

\code{trt.vs.ctrl.emmc} and its relatives generate contrasts for comparing
one level (or the average over specified levels) with each of the other
levels. The argument \code{ref} should be the index(es) (not the labels) of
the reference level(s). \code{trt.vs.ctrl1.emmc} is the same as
\code{trt.vs.ctrl.emmc} with a reference value of 1, and
\code{trt.vs.ctrlk.emmc} is the same as \code{trt.vs.ctrl} with a reference
value of \code{length(levs)}. \code{dunnett.emmc} is the same as
\code{trt.vs.ctrl}. The default multiplicity adjustment method is
\code{"dunnettx"}, a close approximation to the Dunnett adjustment.

\code{consec.emmc} and \code{mean_chg.emmc} are useful for contrasting
treatments that occur in sequence. For a factor with levels A, B, C, D, E,
\code{consec.emmc} generates the comparisons B-A, C-B, and D-C, while
\code{mean_chg.emmc} generates the contrasts (B+C+D)/3 - A, (C+D)/2 -
(A+B)/2, and D - (A+B+C)/3. With \code{reverse = TRUE}, these differences go
in the opposite direction.

\code{eff.emmc} and \code{del.eff.emmc} generate contrasts that compare each 
level with the average over all levels (in \code{eff.emmc}) or over all other
levels (in \code{del.eff.emmc}). These differ only in how they are scaled. 
For a set of k EMMs, \code{del.eff.emmc} gives weight 1 to one EMM and weight
-1/(k-1) to the others, while \code{eff.emmc} gives weights (k-1)/k and -1/k 
respectively, as in subtracting the overall EMM from each EMM. The default 
multiplicity adjustment method is \code{"fdr"}. This is a Bonferroni-based 
method and is slightly conservative; see \code{\link[stats]{p.adjust}}.}

\item{reverse}{Logical value to determine the direction of comparisons}

\item{max.degree}{Integer specifying the maximum degree of polynomial contrasts}

\item{ref}{Integer(s) specifying which level(s) to use as the reference}
}
\value{
A data.frame, each column containing contrast coefficients for levs.
  The "desc" attribute is used to label the results in emmeans, and the
  "adjust" attribute gives the default adjustment method for multiplicity.
}
\description{
Contrast families
}
\examples{
warp.lm <- lm(breaks ~ wool*tension, data = warpbreaks)
warp.emm <- emmeans(warp.lm, ~ tension | wool)
contrast(warp.emm, "poly")

### Setting up a custom contrast function
helmert.emmc <- function(levs, ...) {
    M <- as.data.frame(contr.helmert(levs))
    names(M) <- paste(levs[-1],"vs earlier")
    attr(M, "desc") <- "Helmert contrasts"
    M
}
contrast(warp.emm, "helmert")
\dontrun{
# See what is used for polynomial contrasts with 6 levels
emmeans:::poly.emmc(1:6)
}
}
