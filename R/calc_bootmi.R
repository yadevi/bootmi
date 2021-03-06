#' @title Prepare calculation of bootstrapped confidence intervals.
#' @description
#' This is a helper function to make use of \code{\link[boot]{boot.ci}} method 
#' from boot package.
#' @param boot_object object of class "simpleslopes.bootmi" or 
#' "bootmi.lm"
#' @author Stephan Volpers \email{stephan.volpers@@plixed.de}
#' @export

calc_bootmi <- function ( 
  data
  , indices
  , frmla
  , imputationMethod
  , res_int = FALSE
  , center_mods = FALSE
  , simslopinfo = NA
  ) {
  
  ####
  # Start creating data
  ####

  # draw bootstrap sample
  bootstr_sample <- data[ indices
    , !grepl( "\\.RX\\.", colnames( data))]

  # create residual interactions AFTER bootstrapping, because...
  # ...residuals depend on regression results of each sample
  if( res_int == TRUE ) {
    res <- add_residual_interactions( frmla, bootstr_sample)
    frmla <- res$formula
    data <- res$data
  } else {
    int <- add_interactions( frmla, bootstr_sample)
    frmla <- int$formula
    data <- int$data
  }

    # # correct data and formula with actual values 
    # # after creating residual interactions 
    # # if intercept ommitted
    # if( TRUE %in% grepl( "-1", formula) ) {
    #   # add ommit
    #   f = sub( "~", "~ -1 +", res$formula)
    #   formula = as.formula( paste( f[[2]], f[[1]], f[[3]]))
    # } else {
    #   formula = res$formula
    # }
    # data = res$data

  # extract ids here, needed in case of centering
  ids <- as.numeric( rownames( data))

  # IMPUTE data WHEN RESIDUALS EXIST
  # Check if imputation is needed 
  if( 
    (imputationMethod != "none") 
    && (( sum( is.na( data))) > 0 )
  ) {
    id = as.numeric( rownames( data))
    # impute data
    mids_data <- mice::mice( 
      data
      , method = imputationMethod
      , m = 1
      , print = FALSE
    )
    # convert from mids object to data set
    data <- mice::complete( 
      mids_data
      , action = "long"
      , include = FALSE
    )
    data <- data[ , -c(1,2)]
    rownames(data) <- id
  }

  # Center Variables, if requested
  if( center_mods == TRUE ) { 
    # extract terms
    terms <- attr( terms( as.formula( frmla)), "term.labels")
    # extract interaction terms
    centered_vars <- sapply( terms, function(x) {
      if( grepl( '.RX.', x, fixed = TRUE) 
        || grepl( '.XX.', x, fixed = TRUE) 
        || grepl( ':', x, fixed = TRUE) ) {
        return(x)
      }
    })
    # center interaction terms
    data <- centering( data, unlist(centered_vars))
  }
  rownames(data) <- ids


  ####
  # Apply statistical methods
  ####

  # calculate linear regression
  lmfit <- lm(
    formula = frmla
    , data = data
    )

  # extract model fit statistics
  summarylmfit <- summary(lmfit)
  modelfit <- c(
    summarylmfit$r.squared
    , summarylmfit$adj.r.squared
    , summarylmfit$fstatistic[["value"]]
    )
  names(modelfit) <- c(
    "r.squared"
    , "adj.r.squared"
    , "fstatistic"
    )

  # caculate simple slopes
  simslops <- list()
  if( !is.null(simslopinfo) ) {

    # need x and m be centered ?
    if( center_mods == TRUE | res_int == TRUE ) {
      center <- TRUE
    } else {
      center <- FALSE
    }

    # calculate simple slopes 
    # currently for n independend variables 
    # but one moderator variables
    simslops <- vector(
      "list"
      , eval(
        length(simslopinfo$mod_values)
        *
        length(simslopinfo$x_var)
        ) 
      )
    simslops <- lapply( 
      simslopinfo$x_var
      , function( iv, lmfit, simslopinfo, centered) {
        # calculate simple slopes
        sisl <- simslop(
          object = lmfit
          , x_var = iv
          , m_var = simslopinfo$m_var
          , ci = NULL
          , mod_values_type = simslopinfo$mod_values_type
          , mod_values = simslopinfo$mod_values
          , centered = center
        )
        # extract slope coefficients
        slopes <- unlist(sisl$simple_slopes["slope"])
        # name slope coefficients
        names(slopes) <- paste0( 
          paste0( sisl$info$X,"_X_",sisl$info$M)
          ,"__"
          , sisl$info$Type_of_moderator_values
          ,"__"
          , sisl$info$Values_of_Moderator
          )
        return(slopes)
      }
      , lmfit = lmfit
      , simslopinfo = simslopinfo
      , centered = center
      )

  } # end if simple slopes

  return(
    c(
      coef( lmfit)
      , modelfit
      , unlist( simslops)
      )
    )
}



