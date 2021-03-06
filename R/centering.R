#' @title centers selected variables 
#' @description
#' It is important to center data that is used in the model 
#' AFTER deleting cases of missing values.
#' @param data_set a data.frame 
#' @param centered_vars a vector containing names of variables to center 
#' OR "all" for centering all variables
#' @return data.frame with centered variables
#' @author Stephan Volpers \email{stephan.volpers@@plixed.de}
#' @references \href{http://processmacro.org/faq.html}{Process}
#' @export

centering <- function( data_set, centered_vars= "all") {
	# return data_set id no variables should be centered
	if( length( centered_vars) < 1 ) {
		return( data_set)
	}
	# if "all" => center all variables
	if( length( centered_vars) == 1 && centered_vars == "all" ) {
		centered_vars = colnames( data_set)
	}

	# convert data_set to data frame
	data_set = as.data.frame( data_set)
	# center moderators and save as data.frame
	y = as.data.frame( scale( 
		data_set[ , centered_vars]
		, center= TRUE
		, scale= FALSE)
	)
	# rename columns
	colnames(y) = centered_vars

	# create merge variable
	y$rownames = as.numeric( row.names(y))
	data_set$rownames = as.numeric( row.names(data_set))
	# merge data skipping non centered of centered variables
	if( ( ncol( data_set) - 1) > length( centered_vars) ) {
		data_set = merge( data_set[ , !(names(data_set) %in% centered_vars)], y, by="rownames", all.x=TRUE, sort=TRUE)
	} else {
		data_set = y
	}
	# reset rownames to original data
	row.names( data_set) <- data_set$rownames
	# remove merge variable
	data_set$rownames <- NULL
	# return data
	return(data_set)
}
