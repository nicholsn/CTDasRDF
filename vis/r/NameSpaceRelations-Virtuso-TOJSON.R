###############################################################################
# -----------------------------------------------------------------------------
# FILE : /SDTMasRDF/vis/r/NamespaceRelations-FNGraph.R
# DESCR: Create JSON file consumed by NamespaceRelations-FNGraph.html for display of 
#        relations between the namespaces in the SDTMasRDF named graph
# REQ  : TTL data uploaded to Virtuoso named graph SDTMasRDF running on localhost
# NOTES: visNetwork docs and examples: http://dataknowledge.github.io/visNetwork/
#        For D3js, node ID must start at 0 and progress from there.
#        Node and Edge Types are coded as Upppercase for consistent implmentation 
#          in the CSS
# VIS  : http://localhost:8000/SDTMasRDF/vis/d3/DataRelations-FNGraph.html
# INPUT: /SDTMasRDF/data/rdf/study.ttl
#                           /code.ttl
#                        ....etc., uploaded to Virtuoso & served on localhost
# OUT  : /SDTMasRDF/vis/d3/data/DataRelations-FNGraph.JSON  
#        
# TODO : 
#
###############################################################################
library(rrdf)     # Read / Create RDF
library(reshape)  # melt
library(plyr)     # various goodies
library(jsonlite) # Nice, clean JSON creation

setwd("C:/_gitHub/SDTMasRDF")

#-- Local endpoint
endpoint = "http://localhost:8890/sparql"

# Note how back slashes must be DOUBLE escaped when writing the SPARQL query string
#   within R
#  TODO: Review prefixes from removal: EG:
prefixes = '
PREFIX arg: <http://spinrdf.org/arg#>
PREFIX BRIDG_4.1.1.owl: <file:/Users/Frederik/Downloads/BRIDG_4.1.1.owl.xml>
PREFIX code: <https://github.com/phuse-org/SDTMasRDF/blob/master/data/rdf/code#> 
prefix custom: <https://github.com/phuse-org/SDTMasRDF/blob/master/data/rdf/custom#>
PREFIX EG:    <http://www.example.org/cdiscpilot01#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>

PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX schema: <https://github.com/phuse-org/SDTMasRDF/blob/master/data/rdf/ct/schema#>
PREFIX sdtm-terminology: <https://github.com/phuse-org/SDTMasRDF/blob/master/data/rdf/sdtm-terminology#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX smf: <http://topbraid.org/sparqlmotionfunctions#>
PREFIX sp: <http://spinrdf.org/sp#>
PREFIX spin: <http://spinrdf.org/spin#>
PREFIX spl: <http://spinrdf.org/spl#>
PREFIX study: <https://github.com/phuse-org/SDTMasRDF/blob/master/data/rdf/study#>
PREFIX time: <http://www.w3.org/2006/time#>
prefix xhtm: <http://www.w3.org/1999/xhtml>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
'
# Set a limit for the queries during development
limit = ""
# limit = "limit 1000"

# Currently only looking at code, study, time, protocol namespaces
nameSpaceQuery = '
SELECT *
FROM <http://localhost:8890/SDTMasRDF>
WHERE {
   ?s ?p ?o
   FILTER(regex(str(?s), "(code|study|time|cd01p)#"))
   FILTER(regex(str(?o), "(code|study|time|cd01p)#"))
} '

query<-paste0(prefixes, nameSpaceQuery, limit)
triples = as.data.frame(sparql.remote(endpoint, query))

# Source node type set manually, post-query
triples$srcType[grepl('code:', triples$s)] <- 'code' 
triples$srcType[grepl('study:', triples$s)] <- 'study'      
triples$srcType[grepl('time:', triples$s)] <- 'time'      

# NEW 
# Get the unique list of nodes as needed by the JSON file:
# Combine Subject and Object into a single column
# "id.vars" is the list of columns to keep untouched. The unamed ones are 
# melted into the "value" column.
nodeList <- melt(triples, id.vars=c("p", "srcType" ))   # subject, object into 1 column.

# A node can be both a Subject and a Predicate so ensure a unique list of node names
#  by dropping duplicate values.
nodeList <- nodeList[!duplicated(nodeList$value),]

# Rename the columns 
# TODO: DROP ones not needed!
colnames(nodeList)<-c("p", "srcType", "var", "name")  # column name should be name, not value.

# Rename column value to name for use in nodes list for JSON
nodeList <-arrange(nodeList,name)  # sort

# Create the node ID values starting at 0 (as req. by D3JS)
id<-0:(nrow(nodeList)-1)   # Generate a list of ID numbers
nodeList<-data.frame(id, nodeList)  
head(nodeList)
head(triples)

# Attach the ID values to Subject Nodes
edgesList <- merge (triples, nodeList, by.x="s", by.y="name")

# id becomes the subject node id
edgesList<-rename(edgesList, c("id"="source"))

# Attach ID values to Object Nodes
edgesList <- merge (edgesList, nodeList, by.x="o", by.y="name")
# p is renamed to "value" for use in LINKS dataframe. "value" is needed above here.


edgesList<-rename(edgesList, c("id"="target", "p"="value"))

# Construct edgeType by removing the prefix and converting to 
#  upper case for use in CSS display
edgesList$edgeType<-paste0("EDGE_", toupper(sub("(\\w+):","",edgesList$value)))



head(edgesList)


# Reorder for pretty-pretty
edgesList<-edgesList[c("s", "source", "value", "o", "target", "edgeType")]

nodeList$type <- toupper(nodeList$srcType)
# nodeCategory used for grouping in the FN graph. Assign grouping based on type
#   Make this smarter later: sort on unique type and assign index value.
nodeList$nodeCategory[grepl('CODE',  nodeList$type)] <- '1'      
nodeList$nodeCategory[grepl('STUDY', nodeList$type)] <- '2'      
nodeList$nodeCategory[grepl('TIME',  nodeList$type)] <- '3'      
#nodeList$type[grepl('sdtmc:C', nodeList$name)]<- 'cdisc'  
#nodeList$type[grepl('code:', nodeList$name)]  <- 'code'  

# Later change the following to RegX of code:<UppercaseLetter> to detect
#   all the codelist classes.
#DEL nodeList$freq <-1  # a default value for node size

# nodeList$freq[grepl('code:Sex', nodeList$name)]  <- nodeList$freq*2;
# Adjust node size based on type of node (if needed) 
# nodeList$freq[grepl('code:[A-Z]', nodeList$name)]  <- nodeList$freq*2;

head(nodeList)

nodes<-data.frame(id=nodeList$id,
                  nodeID=nodeList$id,
                  name=nodeList$name,
                  type=nodeList$type,
                  label=nodeList$name,
                  nodeCategory=nodeList$nodeCategory)
# Later can be set based on number of obs, etc.
#nodes$nodesize=4  #

# 2. make the EDGES dataframe that contains: source, target, value columns
#   source, target,
#  named edges instead of links to match D3jS in .html file
edges<- as.data.frame(edgesList[c("source", "target", "value", "edgeType")])


# Combine the nodes and edges into a single dataframe for conversion to JSON
all <- list(nodes=nodes,
            edges=edges)
# Write out to JSON
fileConn<-file("./vis/d3/data/NameSpaceRelations-FROMR.JSON")
writeLines(toJSON(all, pretty=TRUE), fileConn)
close(fileConn)