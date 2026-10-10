args <- commandArgs(trailingOnly=TRUE)
root <- args[[1]]
setwd(root)
results <- list()
observe <- function(label, fun) {
  results[[label]] <<- tryCatch(fun(), error=function(e) list(error=conditionMessage(e)))
}
observe("versions", function() list(R=as.character(getRversion()), frictionless=as.character(packageVersion("frictionless")), rocrateR=as.character(packageVersion("rocrateR"))))
observe("datapackage-read-query-edit", function() {
  p <- frictionless::read_package("multi/datapackage.json")
  paths <- lapply(p$resources, function(r) r$path)
  p$title <- "Edited by R implementation"
  frictionless::write_package(p,"r-edited")
  q <- frictionless::read_package("r-edited/datapackage.json")
  list(resources=frictionless::resources(q), before_paths=paths,
       after_paths=lapply(q$resources,function(r) r$path), relations=q$relations,
       custom=lapply(q$resources,function(r) r$evidence), schema=q$`$schema`)
})
observe("datapackage-non-tabular-content",function() {
  p <- frictionless::read_package("multi/datapackage.json")
  d <- frictionless::read_resource(p,"artifact-0")
  list(class=class(d),dimensions=dim(d))
})
observe("datapackage-create-ordinary-single",function() {
  p <- frictionless::create_package(list(
    `$schema`="https://datapackage.org/profiles/2.0/datapackage.json",
    title="Single historical planning document", directory="single",
    resources=list(list(name="document",path="files/PLAN.md",description="historical document",role="document"))))
  frictionless::write_package(p,"r-created-single")
  list(files=list.files("r-created-single",recursive=TRUE))
})
for (label in c("missing-resources","wrong-title","wrong-schema","missing-file")) {
  observe(paste0("datapackage-negative-",label),local({ n <- label; function() {
    d <- list(directory="multi",resources=list(list(name="probe",path="files/not-present.txt")))
    if(n=="missing-resources") d$resources <- NULL
    if(n=="wrong-title") d$title <- 42
    if(n=="wrong-schema") d$`$schema` <- 42
    p <- frictionless::create_package(d)
    frictionless::check_package(p)
    list(accepted=TRUE)
  }}))
}

observe("rocrate-default-version",function() {
  c <- rocrateR::rocrate(name="Probe",description="Internal archive fixture",datePublished="2026-10-10")
  list(context=c$`@context`,metadata=rocrateR::get_entity(c,"ro-crate-metadata.json"))
})
make_crate <- function(selected, directory, source="multi/files") {
  c <- rocrateR::rocrate(name="Historical snapshot",description="Internal snapshot creation fixture; not public publication",datePublished="2026-10-10",
        context="https://w3id.org/ro/crate/1.3/context",conformsTo="https://w3id.org/ro/crate/1.3")
  ids <- list()
  for (path in selected) {
    id <- paste0("files/",path)
    e <- rocrateR::entity(id,type="File",description="historical evidence",originalPath=path,evidence=list(state="archived"))
    c <- rocrateR::add_entity(c,e)
    ids <- append(ids,list(list(`@id`=id)))
  }
  c <- rocrateR::add_entity_value(c,"./","hasPart",ids,overwrite=TRUE)
  dir.create(directory)
  rocrateR::write_rocrate(c,file.path(directory,"ro-crate-metadata.json"))
  for (path in selected) {
    target <- file.path(directory,"files",path)
    dir.create(dirname(target),recursive=TRUE,showWarnings=FALSE)
    stopifnot(file.copy(file.path(source,path),target))
  }
  c
}
multi <- c("tmp/doc-01-file-url-probe.el","tmp/doc-01-file-url-probe.scm","tmp/doc-01-file-url-probe.txt")
observe("rocrate-create-multi",function() {
  c <- make_crate(multi,"r-rocrate-multi")
  c <- rocrateR::add_entity_value(c,paste0("files/",multi[[1]]),"isRelatedTo",list(`@id`=paste0("files/",multi[[2]])))
  rocrateR::write_rocrate(c,"r-rocrate-multi/ro-crate-metadata.json")
  q <- rocrateR::load_rocrate("r-rocrate-multi/ro-crate-metadata.json")
  v <- rocrateR::validate_rocrate(q,mode="report",strict=TRUE)
  list(context=q$`@context`,files=rocrateR::get_entity(q,type="File"),validation=v)
})
observe("rocrate-create-single",function() {
  c <- make_crate("PLAN.md","r-rocrate-single",source="single/files")
  list(validation=rocrateR::validate_rocrate(c,mode="report",strict=TRUE),entities=length(c$`@graph`))
})
if(file.exists("r-rocrate-multi/ro-crate-metadata.json")) {
  base <- rocrateR::load_rocrate("r-rocrate-multi/ro-crate-metadata.json")
  for(label in c("missing-date","missing-name","wrong-date-type","missing-file","dangling-reference","unknown-schema-context")) {
    observe(paste0("rocrate-negative-",label),local({n <- label; function() {
      c <- base
      if(n=="missing-date") c$`@graph`[[2]]$datePublished <- NULL
      if(n=="missing-name") c$`@graph`[[2]]$name <- NULL
      if(n=="wrong-date-type") c$`@graph`[[2]]$datePublished <- 42
      if(n=="missing-file") c$`@graph`[[3]]$`@id` <- "files/no-such-file.txt"
      if(n=="dangling-reference") c$`@graph`[[2]]$hasPart <- list(list(`@id`="files/missing.txt"))
      if(n=="unknown-schema-context") c$`@context` <- "https://example.invalid/context"
      list(validation=rocrateR::validate_rocrate(c,mode="report",strict=TRUE))
    }}))
  }
  observe("rocrate-edit-roundtrip",function() {
    c <- rocrateR::add_entity_value(base,"files/tmp/doc-01-file-url-probe.el","description","edited",overwrite=TRUE)
    rocrateR::write_rocrate(c,"r-rocrate-edited.json")
    q <- rocrateR::load_rocrate("r-rocrate-edited.json")
    list(entity=rocrateR::get_entity(q,"files/tmp/doc-01-file-url-probe.el"),validation=rocrateR::validate_rocrate(q,mode="report",strict=TRUE))
  })
}
plain <- function(x) if(is.list(x)) lapply(unclass(x),plain) else x
jsonlite::write_json(plain(results),"r-results.json",pretty=TRUE,auto_unbox=TRUE,null="null")
print(results)
