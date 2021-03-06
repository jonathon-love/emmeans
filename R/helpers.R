##############################################################################
#    Copyright (c) 2012-2017 Russell V. Lenth                                #
#                                                                            #
#    This file is part of the emmeans package for R (*emmeans*)              #
#                                                                            #
#    *emmeans* is free software: you can redistribute it and/or modify       #
#    it under the terms of the GNU General Public License as published by    #
#    the Free Software Foundation, either version 2 of the License, or       #
#    (at your option) any later version.                                     #
#                                                                            #
#    *emmeans* is distributed in the hope that it will be useful,            #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of          #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           #
#    GNU General Public License for more details.                            #
#                                                                            #
#    You should have received a copy of the GNU General Public License       #
#    along with R and *emmeans*.  If not, see                                #
#    <https://www.r-project.org/Licenses/> and/or                            #
#    <http://www.gnu.org/licenses/>.                                         #
##############################################################################

### Helper functions for emmeans
### Here we have 'recover_data' and 'emm_basis' methods
### For models that this package supports.

#--------------------------------------------------------------
### lm objects (and also aov, rlm, others that inherit) -- but NOT aovList
#' @method recover_data lm
#' @export
recover_data.lm = function(object, ...) {
        fcall = object$call
    recover_data(fcall, delete.response(terms(object)), object$na.action, ...)
}

#' @export
emm_basis.lm = function(object, trms, xlev, grid, ...) {
    # coef() works right for lm but coef.aov tosses out NAs
    bhat = object$coefficients
    nm = if(is.null(names(bhat))) row.names(bhat) else names(bhat)
    m = suppressWarnings(model.frame(trms, grid, na.action = na.pass, xlev = xlev))
    X = model.matrix(trms, m, contrasts.arg = object$contrasts)[, nm, drop = FALSE]
    bhat = as.numeric(bhat) 
    # stretches it out if multivariate - see mlm method
    V = .my.vcov(object, ...)
    
    if (sum(is.na(bhat)) > 0)
        nbasis = estimability::nonest.basis(object$qr)
    else
        nbasis = estimability::all.estble
    misc = list()
    if (inherits(object, "glm")) {
        misc = .std.link.labels(object$family, misc)
        dffun = function(k, dfargs) Inf
        dfargs = list()
    }
    else {
        dfargs = list(df = object$df.residual)
        dffun = function(k, dfargs) dfargs$df
    }
    list(X=X, bhat=bhat, nbasis=nbasis, V=V, dffun=dffun, dfargs=dfargs, misc=misc)
}



#--------------------------------------------------------------
### mlm objects
# (recover_data.lm works just fine)

#' @export
emm_basis.mlm = function(object, trms, xlev, grid, ...) {
    class(object) = c("mlm", "lm") # avoids error in vcov for "maov" objects
    bas = emm_basis.lm(object, trms, xlev, grid, ...)
    bhat = coef(object)
    k = ncol(bhat)
    bas$X = kronecker(diag(rep(1,k)), bas$X)
    bas$nbasis = kronecker(rep(1,k), bas$nbasis)
    ylevs = dimnames(bhat)[[2]]
    if (is.null(ylevs)) ylevs = seq_len(k)
    bas$misc$ylevs = list(rep.meas = ylevs)
    bas
}



#--------------------------------------------------------------
### merMod objects (lme4 package)
#' @export
recover_data.merMod = function(object, ...) {
    if(!lme4::isLMM(object) && !lme4::isGLMM(object)) 
        return("Can't handle a nonlinear mixed model")
    fcall = object@call
    recover_data(fcall, delete.response(terms(object)), 
                 attr(object@frame, "na.action"), ...)
}

#' @export
emm_basis.merMod = function(object, trms, xlev, grid, vcov., 
                            mode = get_emm_option("lmer.df"), 
                            lmer.df, ...) {
    if (missing(vcov.))
        V = as.matrix(vcov(object, correlation = FALSE))
    else
        V = as.matrix(.my.vcov(object, vcov.))
    dfargs = misc = list()
    
    if (lme4::isLMM(object)) {
        # Allow lmer.df in lieu of mode
        if (!missing(lmer.df))
            mode = lmer.df

        mode = match.arg(tolower(mode), c("satterthwaite", "kenward-roger", "asymptotic"))
        
        # set flags
        objN = lme4::getME(object, "N")
        disable.pbkrtest = get_emm_option("disable.pbkrtest")
        tooBig.k = (objN > get_emm_option("pbkrtest.limit"))
        disable.lmerTest = get_emm_option("disable.lmerTest")
        tooBig.s = (objN > get_emm_option("lmerTest.limit"))
        
        tooBigMsg = function(pkg, limit) {  
            message("Note: D.f. calculations have been",
                    " disabled because the number of observations exceeds ", limit, ".\n",
                    "To enable adjustments, set emm_options(", pkg, ".limit = ", objN, ") or larger,\n",
                    "but be warned that this may result in large computation time and memory use.")
        }
        
        if ((mode == "kenward-roger") && !disable.pbkrtest && requireNamespace("pbkrtest")) {
            if (!disable.pbkrtest && !tooBig.k  && missing(vcov.)) {
                dfargs = list(unadjV = V, 
                              adjV = pbkrtest::vcovAdj.lmerMod(object, 0))
                V = as.matrix(dfargs$adjV)
                tst = try(pbkrtest::Lb_ddf)
                if(class(tst) != "try-error")
                    dffun = function(k, dfargs) pbkrtest::Lb_ddf (k, dfargs$unadjV, dfargs$adjV)
                else {
                    mode = "asymptotic"
                    warning("Failure in loading pbkrtest routines - reverted to \"asymptotic\"")
                }
            }
            else if(tooBig.k) {
                tooBigMsg("pbkrtest", get_emm_option("pbkrtest.limit"))
                mode = "asymptotic"
            }
            else if (!missing(vcov.)) {
                message("Kenward-Roger method can't be used with user-supplied covariances")
                mode = "satterthwaite"
            }
        }
        if (mode == "satterthwaite" && !disable.lmerTest && requireNamespace("lmerTest")) {
            if (!tooBig.s) {
                dfargs = list(object = object)
                dffun = function(k, dfargs) 
                    suppressMessages(lmerTest::calcSatterth(dfargs$object, k)$denom)
            }
            else {
                tooBigMsg("lmerTest", get_emm_option("lmerTest.limit"))
                mode = "asymptotic"
            }
        }
        if (mode == "asymptotic") {
            dffun = function(k, dfargs) Inf
        }
        misc$initMesg = paste("Degrees-of-freedom method:", mode)
    }
    else if (lme4::isGLMM(object)) {
        dffun = function(k, dfargs) Inf
        misc = .std.link.labels(family(object), misc)
    }
    else 
        stop("Can't handle a nonlinear mixed model")
    
    contrasts = attr(object@pp$X, "contrasts")
    m = model.frame(trms, grid, na.action = na.pass, xlev = xlev)
    X = model.matrix(trms, m, contrasts.arg = contrasts)
    bhat = lme4::fixef(object)
    
    if (length(bhat) < ncol(X)) {
        # Newer versions of lmer can handle rank deficiency, but we need to do a couple of
        # backflips to put the pieces together right,
        # First, figure out which columns were retained
        kept = match(names(bhat), dimnames(X)[[2]])
        # Now re-do bhat with NAs in the right places
        bhat = NA * X[1, ]
        bhat[kept] = lme4::fixef(object)
        # we have to reconstruct the model matrix
        modmat = model.matrix(trms, object@frame, contrasts.arg=contrasts)
        nbasis = estimability::nonest.basis(modmat)
    }
    else
        nbasis=estimability::all.estble
    
    list(X=X, bhat=bhat, nbasis=nbasis, V=V, dffun=dffun, dfargs=dfargs, misc=misc)
}




#--------------------------------------------------------------
### lme objects (nlme package)
#' @export
recover_data.lme = function(object, data, ...) {
    fcall = object$call
    if (!is.null(fcall$weights))
        fcall$weights = nlme::varWeights(object$modelStruct)
    recover_data(fcall, delete.response(object$terms), object$na.action, data = data, ...)
}

#' @export
emm_basis.lme = function(object, trms, xlev, grid, sigmaAdjust = TRUE, ...) {
    contrasts = object$contrasts
    m = model.frame(trms, grid, na.action = na.pass, xlev = xlev)
    X = model.matrix(trms, m, contrasts.arg = contrasts)
    bhat = nlme::fixef(object)
    V = .my.vcov(object, ...)
    if (sigmaAdjust && object$method == "ML") 
        V = V * object$dims$N / (object$dims$N - nrow(V))
    misc = list()
    if (!is.null(object$family)) {
        misc = .std.link.labels(object$family, misc)
    }
    nbasis = estimability::all.estble
    # Replaced by containment method##dffun = function(...) NA
    dfx = object$fixDF$X
    if (names(bhat[1]) == "(Intercept)")
        dfx[1] = length(levels(object$groups[[1]])) - 1#min(dfx)   ### Correct apparent error in lme containment algorithm
    dffun = function(x, dfargs) {
        idx = which(abs(x) > 1e-4)
        ifelse(length(idx) > 0, min(dfargs$dfx[idx]), NA)
    }
    list(X = X, bhat = bhat, nbasis = nbasis, V = V, 
         dffun = dffun, dfargs = list(dfx = dfx), misc = misc)
}



#--------------------------------------------------------------
### gls objects (nlme package)
recover_data.gls = function(object, ...) {
    fcall = object$call
    if (!is.null(fcall$weights))
        fcall$weights = nlme::varWeights(object$modelStruct)
    trms = delete.response(terms(nlme::getCovariateFormula(object)))
    recover_data(fcall, trms, object$na.action, ...)
}

emm_basis.gls = function(object, trms, xlev, grid, ...) {
    contrasts = object$contrasts
    m = model.frame(trms, grid, na.action = na.pass, xlev = xlev)
    X = model.matrix(trms, m, contrasts.arg = contrasts)
    bhat = coef(object)
    V = .my.vcov(object, ...)
    nbasis = estimability::all.estble
    dfargs = list(df = object$dims$N - object$dims$p)
    dffun = function(k, dfargs) dfargs$df
    list(X=X, bhat=bhat, nbasis=nbasis, V=V, dffun=dffun, dfargs=dfargs, misc=list())
}



#--------------------------------------------------------------
### polr objects (MASS package)
recover_data.polr = function(object, ...)
    recover_data.lm(object, ...)

emm_basis.polr = function(object, trms, xlev, grid, 
                          mode = c("latent", "linear.predictor", "cum.prob", "exc.prob", "prob", "mean.class"), 
                          rescale = c(0,1), ...) {
    mode = match.arg(mode)
    contrasts = object$contrasts
    m = model.frame(trms, grid, na.action = na.pass, xlev = xlev)
    X = model.matrix(trms, m, contrasts.arg = contrasts)
    # Strip out the intercept (borrowed code from predict.polr)
    xint = match("(Intercept)", colnames(X), nomatch = 0L)
    if (xint > 0L) 
        X = X[, -xint, drop = FALSE]
    bhat = c(coef(object), object$zeta)
    V = .my.vcov(object, ...)
    k = length(object$zeta)
    if (mode == "latent") {
        X = rescale[2] * cbind(X, matrix(- 1/k, nrow = nrow(X), ncol = k))
        bhat = c(coef(object), object$zeta - rescale[1] / rescale[2])
        misc = list(offset.mult = rescale[2])
    }
    else {
        j = matrix(1, nrow=k, ncol=1)
        J = matrix(1, nrow=nrow(X), ncol=1)
        X = cbind(kronecker(-j, X), kronecker(diag(1,k), J))
        link = object$method
        if (link == "logistic") link = "logit"
        misc = list(ylevs = list(cut = names(object$zeta)), 
                    tran = link, inv.lbl = "cumprob", offset.mult = -1)
        if (mode != "linear.predictor") {
            # just use the machinery we already have for the 'ordinal' package
            misc$mode = mode
            misc$postGridHook = ".clm.postGrid"
        }
    }
    misc$respName = as.character(terms(object))[2]
    nbasis = estimability::all.estble
    dffun = function(...) Inf
    list(X=X, bhat=bhat, nbasis=nbasis, V=V, dffun=dffun, dfargs=list(), misc=misc)
}




#--------------------------------------------------------------
### survreg objects (survival package)
recover_data.survreg = function(object, ...) {
    fcall = object$call
    trms = delete.response(terms(object))
    # I'm gonna delete any terms involving strata(), cluster(), or frailty()
    mod.elts = dimnames(attr(trms, "factor"))[[2]]
    tmp = grep("strata\\(|cluster\\(|frailty\\(", mod.elts)
    if (length(tmp))
        trms = trms[-tmp]
    recover_data(fcall, trms, object$na.action, ...)
}

# Seems to work right in a little testing.
# However, it fails sometimes if I update the model 
# with a subset argument. Workaround: just fitting a new model
emm_basis.survreg = function(object, trms, xlev, grid, ...) {
    # Much of this code is adapted from predict.survreg
    bhat = object$coefficients
    k = length(bhat)
    V = .my.vcov(object, ...)[seq_len(k), seq_len(k), drop=FALSE]
    # ??? not used... is.fixeds = (k == ncol(object$var))
    m = model.frame(trms, grid, na.action = na.pass, xlev = xlev)    
    # X = model.matrix(object, m) # This is what predict.survreg does
    # But I have manipulated trms, so need to make sure things are consistent
    X = model.matrix(trms, m, contrasts.arg = object$contrasts)
    nbasis = estimability::nonest.basis(model.matrix(object))
    dfargs = list(df = object$df.residual)
    dffun = function(k, dfargs) dfargs$df
    if (object$dist %in% c("exponential","weibull","loglogistic","loggaussian","lognormal")) 
        misc = list(tran = "log", inv.lbl = "response")
    else 
        misc = list()
    misc$postGridHook = .notran2   # removes "Surv()" as response transformation
    list(X=X, bhat=bhat, nbasis=nbasis, V=V, dffun=dffun, dfargs=dfargs, misc=misc)
}



#--------------------------------------------------------------
###  coxph objects (survival package)
recover_data.coxph = function(object, ...) 
    recover_data.survreg(object, ...)

emm_basis.coxph = function (object, trms, xlev, grid, ...) 
{
    object$dist = "doesn't matter"
    result = emm_basis.survreg(object, trms, xlev, grid, ...)
    result$dfargs$df = NA
    result$X = result$X[, -1, drop = FALSE]
    result$X = result$X - rep(object$means, each = nrow(result$X))
    result$misc$tran = "log"
    result$misc$inv.lbl = "hazard"
    result$misc$postGridHook = .notran2   # removes "Surv()" as response transformation
    result
}

.notran2 = function(object) {
    object@misc$tran2 = NULL
    object
}

# Note: Very brief experimentation suggests coxph.penal also works.
# This is an extension of coxph


#--------------------------------------------------------------
###  coxme objects ####
### Greatly revised 6-15-15 (after version 2.18)
recover_data.coxme = function(object, ...) 
    recover_data.survreg(object, ...)

emm_basis.coxme = function(object, trms, xlev, grid, ...) {
    bhat = fixef(object)
    k = length(bhat)
    V = .my.vcov(object, ...)[seq_len(k), seq_len(k), drop = FALSE]
    m = model.frame(trms, grid, na.action = na.pass, xlev = xlev)
    X = model.matrix(trms, m)
    X = X[, -1, drop = FALSE] # remove the intercept
    # scale the linear predictor
    for (j in seq_along(X[1, ]))
        X[, j] = (X[, j] - object$means[j]) ### / object$scale[j]
    nbasis = estimability::all.estble
    dffun = function(k, dfargs) Inf
    misc = list(tran = "log", inv.lbl = "hazard")
    misc$postGridHook = .notran2   # removes "Surv()" as response transformation
    list(X = X, bhat = bhat, nbasis = nbasis, V = V, dffun = dffun, 
         dfargs = list(), misc = misc)
}


###  special vcov prototype for cases where there are several vcov options
###  e.g., gee, geeglm, geese
.named.vcov = function(object, method, ...)
    UseMethod(".named.vcov")

# default has optional idx of same length as valid and if so, idx indicating 
#   which elt of valid to use if matched
# Ex: valid = c("mammal", "fish", "rat", "dog", "trout", "perch")
#     idx   = c(   1,        2,     1,     1,       2,       2)
#     -- so ultimately results can only be "mammal" or "fish"
# nonmatches revert to 1st elt.
.named.vcov.default = function(object, method, valid, idx = seq_along(valid), ...) {
    if (!is.character(method)) { # in case vcov. arg was matched by vcov.method {
        V = .my.vcov(object, method)
        method = "user-supplied"
    }
    else {
        i = pmatch(method, valid, 1)
        method = valid[idx[i]]
        V = object[[method]]
    }
    attr(V, "methMesg") = paste("Covariance estimate used:", method)
    V
}

# general-purpose emm_basis function
.emmb.geeGP = function(object, trms, xlev, grid, vcov.method, valid, idx = seq_along(valid), ...) {
    m = model.frame(trms, grid, na.action = na.pass, xlev = xlev)
    X = model.matrix(trms, m, contrasts.arg = object$contrasts)
    bhat = coef(object)
    V = .named.vcov(object, vcov.method, valid, idx, ...)
    
    if (sum(is.na(bhat)) > 0)
        nbasis = estimability::nonest.basis(object$qr)
    else
        nbasis = estimability::all.estble
    
    misc = .std.link.labels(object$family, list())
    misc$initMesg = attr(V, "methMesg")
    dffun = function(k, dfargs) Inf
    dfargs = list()
    list(X=X, bhat=bhat, nbasis=nbasis, V=V, dffun=dffun, dfargs=dfargs, misc=misc)
}

#---------------------------------------------------------------
###  gee objects  ####


recover_data.gee = recover_data.lm

emm_basis.gee = function(object, trms, xlev, grid, vcov.method = "robust.variance", ...)
    .emmb.geeGP(object, trms, xlev, grid, vcov.method, 
                valid = c("robust.variance", "naive.variance"))

###  geepack objects  ####
recover_data.geeglm = recover_data.lm

emm_basis.geeglm = function(object, trms, xlev, grid, vcov.method = "vbeta", ...) {
    m = model.frame(trms, grid, na.action = na.pass, xlev = xlev)
    X = model.matrix(trms, m, contrasts.arg = object$contrasts)
    bhat = coef(object)
    V = .named.vcov(object$geese, vcov.method, 
                    valid = c("vbeta", "vbeta.naiv","vbeta.j1s","vbeta.fij","robust","naive"), 
                    idx = c(1,2,3,4,1,2))
    
    if (sum(is.na(bhat)) > 0)
        nbasis = estimability::nonest.basis(object$qr)
    else
        nbasis = estimability::all.estble
    
    misc = .std.link.labels(object$family, list())
    misc$initMesg = attr(V, "methMesg")
    dffun = function(k, dfargs) Inf
    dfargs = list()
    list(X=X, bhat=bhat, nbasis=nbasis, V=V, dffun=dffun, dfargs=dfargs, misc=misc)
}


recover_data.geese = function(object, ...) {
    fcall = object$call
    # what a pain - we need to reconstruct the terms component
    args = as.list(fcall[-1])
    na.action = object$na.action
    #trms = terms.formula(fcall$formula)
    if (!is.null(args$data)) {
        data = eval(args$data, parent.frame())
        trms = terms(model.frame(fcall$formula, data = data))
    } else {
        trms = terms(model.frame(fcall$formula))
    }
    recover_data(fcall, delete.response(trms), na.action, ...)
}

emm_basis.geese = function(object, trms, xlev, grid, vcov.method = "vbeta", ...) {
    m = model.frame(trms, grid, na.action = na.pass, xlev = xlev)
    X = model.matrix(trms, m, contrasts.arg = object$contrasts)
    bhat = object$beta
    V = .named.vcov(object, vcov.method, 
                    valid = c("vbeta", "vbeta.naiv","vbeta.j1s","vbeta.fij","robust","naive"), 
                    idx = c(1,2,3,4,1,2))

    # We don't have the qr component - I'm gonna punt for now
     if (sum(is.na(bhat)) > 0)
         warning("There are non-estimable functions, but estimability is NOT being checked")
#         nbasis = estimability::nonest.basis(object$qr)
#     else
        nbasis = estimability::all.estble
    
    misc = list()
    if (!is.null(fam <- object$call$family))
        misc = .std.link.labels(eval(fam)(), misc)
    misc$initMesg = attr(V, "methMesg")
    dffun = function(k, dfargs) Inf
    dfargs = list()
    list(X=X, bhat=bhat, nbasis=nbasis, V=V, dffun=dffun, dfargs=dfargs, misc=misc)
}




#--------------------------------------------------------------
### glmmADMB package

recover_data.glmmadmb = recover_data.lm

emm_basis.glmmadmb = function (object, trms, xlev, grid, ...) 
{
    contrasts = object$contrasts
    m = model.frame(trms, grid, na.action = na.pass, xlev = xlev)
    X = model.matrix(trms, m, contrasts.arg = contrasts)
    bhat = glmmADMB::fixef(object)
    V = .my.vcov(object, ...)
    misc = list()
    if (!is.null(object$family)) {
        fam = object$family
        misc$tran = object$link
        misc$inv.lbl = "response"
        if (!is.na(pmatch(fam,"binomial"))) 
            misc$inv.lbl = "prob"
        else if (!is.na(pmatch(fam,"poisson"))) 
            misc$inv.lbl = "rate"
    }
    nbasis = estimability::all.estble
    dffun = function(...) Inf
    list(X = X, bhat = bhat, nbasis = nbasis, V = V, dffun = dffun, 
         dfargs = list(), misc = misc)
}


# --------------------------------------------------------------
### Explicit non-support for 'gam' objects (runs, but results are wrong)

# emm_basis.gam = function(object, trms, xlev, grid, ...) {
#     stop("Can't handle an object of class ", dQuote(class(object)[1]), "\n",
#          .show_supported())
# }






### ----- Auxiliary routines -------------------------
# Provide for vcov. argument in ref_grid call, which could be a function or a matrix

.statsvcov = function(object, ...)
    stats::vcov(object, complete = FALSE, ...)

#' @export
.my.vcov = function(object, vcov. = .statsvcov, ...) {
    if (is.function(vcov.))
        vcov. = vcov.(object)
    else if (!is.matrix(vcov.))
        stop("vcov. must be a function or a square matrix")
    vcov.
}

# Call this to do the standard stuff with link labels
# Returns a modified misc
.std.link.labels = function(fam, misc) {
    if (is.null(fam) || !is.list(fam))
        return(misc)
    if (fam$link == "identity")
        return(misc)
    misc$tran = fam$link
    misc$inv.lbl = "response"
    if (length(grep("binomial", fam$family)) == 1)
        misc$inv.lbl = "prob"
    else if (length(grep("poisson", fam$family)) == 1)
        misc$inv.lbl = "rate"
    misc
}


