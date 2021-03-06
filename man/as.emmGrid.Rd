% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/emmeans.R
\name{as.emmGrid}
\alias{as.emmGrid}
\alias{as.list.emmGrid}
\title{Convert to and from \code{emmGrid} objects}
\usage{
as.emmGrid(object, ...)

\method{as.list}{emmGrid}(x, ...)
}
\arguments{
\item{object}{Object to be converted to class \code{emmGrid}. It may
be a \code{list} returned by \code{as.list.emmGrid}, or a \code{ref.grid}
or \code{lsmobj} object created by \pkg{emmeans}'s predecessor, the 
\pkg{lsmeans} package. An error is thrown if \code{object} cannot
be converted.}

\item{...}{In \code{as.emmGrid}, additional arguments passed to 
\code{\link{update.emmGrid}} before returning the object. This
argument is ignored in \code{as.list.emmGrid}}

\item{x}{An \code{emmGrid} object}
}
\value{
\code{as.emmGrid} returns an object of class \code{emmGrid}.

\code{as.list.emmGrid} returns an object of class \code{list}.
}
\description{
These are useful utility functions for creating a compact version of an
\code{emmGrid} object that may be saved and later reconstructed, or for
converting old \code{ref.grid} or \code{lsmobj} objects into \code{emmGrid}
objects.
}
\details{
An \code{emmGrid} object is an S4 object, and as such cannot be saved in a
text format or saved without a lot of overhead. By using \code{as.list},
the essential parts of the object are converted to a list format that can be
easily and compactly saved for use, say, in another session or by another user.
Providing this list as the arguments for \code{\link{emmobj}} allows the user 
to restore a working \code{emmGrid} object.
}
\examples{
pigs.lm <- lm(log(conc) ~ source + factor(percent), data = pigs)
pigs.sav <- as.list(ref_grid(pigs.lm))

pigs.anew <- as.emmGrid(pigs.sav)
emmeans(pigs.anew, "source")

\dontrun{
## Convert an entire workspace saved from an old **lsmeans** session
a.problem <- lsmeans::lsmeans(pigs.lm, "source")
#- Now global env contains at least two ref.grid and lsmobj objects,
#- and the "lsmeans" namespace is loaded
emmeans:::convert_workspace()
class(a.problem)
"lsmeans" \%in\% loadedNamespaces()
#- It's all better now
}
}
\seealso{
\code{\link{emmobj}}
}
