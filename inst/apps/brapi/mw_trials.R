
trials_data = tryCatch({
  res <- read.csv(system.file("apps/brapi/data/trials.csv", package = "brapiTS"),
                  stringsAsFactors = FALSE)
}, error = function(e) {
  NULL
}
)

studies_data = tryCatch({
  res <- read.csv(system.file("apps/brapi/data/studies.csv", package = "brapiTS"),
                  stringsAsFactors = FALSE)[, 1:12]
}, error = function(e) {
  NULL
}
)

trials_additionalInfo_data = tryCatch({
  res <- read.csv(system.file("apps/brapi/data/trials_additionalinfo.csv",
                              package = "brapiTS"),
                  stringsAsFactors = FALSE)
}, error = function(e) {
  NULL
}
)


trials_list = function(programDbId = "any", locationDbId = "any",
                       active = "any",
                       sortBy = "none", sortOrder = "asc",
                       page = 0, pageSize = 100,
                       trialDbId = "any"){


  if(trialDbId != "any") {
    trials_data <- trials_data[trials_data$trialDbId == trialDbId, ]
    if(nrow(trials_data) == 0) return(NULL)
  }


  if(programDbId != "any") {
    trials_data <- trials_data[trials_data$programDbId == programDbId, ]
    if(nrow(trials_data) == 0) return(NULL)
  }

  if(active != "any") {
    trials_data <- trials_data[trials_data$active == active, ]
    if(nrow(trials_data) == 0) return(NULL)
  }

  if(locationDbId != "any" & programDbId != "any") {
    studies_data <- studies_data[studies_data$locationDbId == locationDbId & studies_data$programDbId == programDbId, ]
    if(nrow(studies_data) == 0) return(NULL)
    trials_data <- trials_data[trials_data$trialDbId == studies_data$trialDbId, ]
    if(nrow(trials_data) == 0) return(NULL)
  }

  if(sortBy != "none" & sortBy %in% colnames(trials_data)){
    dcr = ifelse(sortOrder == "asc", FALSE, TRUE)
    trials_data <- trials_data[ order( trials_data[, sortBy], decreasing = dcr), ]
  }

  # paging here after filtering
  pg = paging(trials_data, page, pageSize)
  trials_data <- trials_data[pg$recStart:pg$recEnd, ]

  n = nrow(trials_data)
  out = list(n)
  for(i in 1:n){
    out[[i]] <- trials_data[i, ]
    # Note: additionalInfo insertion fails if only one column has a value in a row

    studiesd = studies_data[studies_data$trialDbId == trials_data$trialDbId[i], c("studyDbId", "studyName", "locationName")]
    if(nrow(studiesd) == 0) {
      studieso = list()
      #return(NULL)
    } else {
      o = nrow(studiesd)
      studieso = list(o)
      for(k in 1:o){
        studieso[[k]] = as.list(studiesd[k, ])
      }

    }
    out[[i]]$studies = list(studieso)

    additionalInfo =
      trials_additionalInfo_data[trials_additionalInfo_data$trialDbId == trials_data$trialDbId[i],
                                    -c(1)]
    if(nrow(additionalInfo) == 0) {
      additionalInfo = NULL
    } else {
      additionalInfo = additionalInfo[, !is.na(additionalInfo)  %>% as.logical() ]
      additionalInfo = as.list(additionalInfo)
    }
    out[[i]]$additionalInfo = list(additionalInfo)
  }

  attr(out, "status") = list()
  attr(out, "pagination") = pg$pagination
  out
}


trials = list(
  metadata = list(
    pagination = list(
      pageSize = 1000,
      currentPage = 0,
      totalCount = nrow(trials_data),
      totalPages = 1
    ),
    status = list(),
    datafiles = list()
  ),
  result =  list(data = trials_list())
)



process_trials <- function(req, res, err){
  prms <- names(req$params)

  programDbId = ifelse('programDbId' %in% prms, req$params$programDbId, "any")
  locationDbId = ifelse('locationDbId' %in% prms, req$params$locationDbId, "any")
  active = ifelse('active' %in% prms, req$params$active, "any")
  sortBy = ifelse('sortBy' %in% prms, req$params$sortBy, "none")
  sortOrder = ifelse('sortOrder' %in% prms, req$params$sortOrder, "asc")

  page = ifelse('page' %in% prms, as.integer(req$params$page), 0)
  pageSize = ifelse('pageSize' %in% prms, as.integer(req$params$pageSize), 1000)



  trials$result$data = trials_list(programDbId, locationDbId, active, sortBy, sortOrder,
                              page, pageSize)
  trials$metadata$pagination = attr(trials$result$data, "pagination")#,
                            #status = attr(trials$result, "status"),
                            #datafiles = list())

  if(is.null(trials$result$data)){
    res$set_status(404)
    trials$metadata <-
      brapi_status(100,"No matching results.!"
                   , trials$metadata$status)
    trials$result = list()
  }

  res$set_header("Access-Control-Allow-Methods", "GET")
  res$json(trials)

}


process_trialsbyid <- function(req, res, err){
  trialDbId <- basename(req$path)
  #message(trialDbId)

  trials$result$data = trials_list(trialDbId = trialDbId)

  if(is.null(trials$result$data)){
    res$set_status(404)
    trials$metadata <-
      brapi_status(100,"No matching results.!"
                   , trials$metadata$status)
    trials$result = list()
  } else {
    trials$metadata$pagination$totalCount = 1
  }

  res$set_header("Access-Control-Allow-Methods", "GET")
  res$json(trials)

}


mw_trials <<-
  collector() %>%
  get("/brapi/v1/trials[/]?", function(req, res, err){
    process_trials(req, res, err)
  })  %>%
  put("/brapi/v1/trials[/]?", function(req, res, err){
    res$set_status(405)
  }) %>%
  post("/brapi/v1/trials[/]?", function(req, res, err){
    res$set_status(405)
  }) %>%
  delete("/brapi/v1/trials[/]?", function(req, res, err){
    res$set_status(405)
  })%>%

  get("/brapi/v1/trials/[0-9a-zA-Z]{1,12}[/]?", function(req, res, err){
    process_trialsbyid(req, res, err)
  })  %>%
  put("/brapi/v1/trials/[0-9a-zA-Z]{1,12}[/]?", function(req, res, err){
    res$set_status(405)
  }) %>%
  post("/brapi/v1/trials/[0-9a-zA-Z]{1,12}[/]?", function(req, res, err){
    res$set_status(405)
  }) %>%
  delete("/brapi/v1/trials/[0-9a-zA-Z]{1,12}[/]?", function(req, res, err){
    res$set_status(405)
  })

