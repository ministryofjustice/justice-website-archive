#!/bin/bash
#########################################################
## --- --- --- --- --- --- --- --- --- --- --- --- --- ##
## --    I N D E X   F I L E   G E N E R A T O R    -- ##
## --- --- --- --- --- --- --- --- --- --- --- --- --- ##
## --- ---                                     --- --- ##
## --- --         Ministry of Justice UK        -- --- ##
## --- -       Central Digital Product Team      - --- ##
## --- --                                       -- --- ##
#########################################################

## Path of output index.html file
OUTPUT="/archiver/snapshots/index.html"

## Temporary data-holder files to help reverse-sort results from AWS S3
DOMAINS="/archiver/snapshots/domains"
DOMAIN_ARCHIVES="/archiver/snapshots/domain_archives"
DOMAIN_ARCHIVES_TEMP="/archiver/snapshots/domain_archives_temp"

## Get archive bucket contents. Later we will discard actual
## objects, we are interested in "directories", tagged with "PRE"
ROOT=$(aws s3 ls s3://"${S3_BUCKET_NAME}"/)

## Begin building HTML - Uses styling from Bootstrap.
{
  echo "<!doctype html><html lang=\"en\"><head><title>Justice Archive Index</title>"
  echo '<style>main{display:block}a{background-color:transparent;color:#337ab7;text-decoration:none;text-shadow:#fff 1px 0 10px;}.list-group-item,body{background-color:#fff}a:active,a:hover{outline:0}h1{font-size:2em;margin:.67em 0}*,:after,:before{-webkit-box-sizing:border-box;-moz-box-sizing:border-box;box-sizing:border-box}html{font-family:sans-serif;-ms-text-size-adjust:100%;-webkit-text-size-adjust:100%;font-size:10px;-webkit-tap-highlight-color:transparent}body{margin:0;font-family:"Helvetica Neue",Helvetica,Arial,sans-serif;font-size:14px;line-height:1.42857143;color:#333}a:focus,a:hover{color:#23527c;text-decoration:underline}a:focus{outline:-webkit-focus-ring-color auto 5px;outline-offset:-2px}.container{padding-right:15px;padding-left:15px;margin-right:auto;margin-left:auto}@media (min-width:768px){.container{width:750px}}@media (min-width:992px){.container{width:970px}}@media (min-width:1200px){.container{width:1170px}}.list-group{padding-left:0;margin-bottom:20px;display:grid;grid-template-columns:repeat(auto-fill,minmax(160px,1fr))}.list-group-item{position:relative;display:block;padding:14px 18px;margin:0 20px 25px 0;background: #fff;-webkit-box-shadow: 0 1px 4px rgba(0, 0, 0, 0.3), 0 0 40px rgba(0, 0, 0, 0.1) inset;-moz-box-shadow: 0 1px 4px rgba(0, 0, 0, 0.3), 0 0 40px rgba(0, 0, 0, 0.1) inset;box-shadow: 0 1px 4px rgba(0, 0, 0, 0.3), 0 0 40px rgba(0, 0, 0, 0.1) inset;}.container:after,.container:before{display:table;content:" "}.container:after{clear:both}.list-group{-webkit-box-shadow:0 1px 2px rgba(0,0,0,.075);box-shadow:0 1px 2px rgba(0,0,0,.075)}</style>'
  echo '</head><body><main>'
} > "$OUTPUT"

echo "<div class=\"container px-4 py-5\"><h1>Ministry of Justice Archiver</h1>" >> "$OUTPUT"

## Get a list of archived domains
rm "$DOMAINS" 2> /dev/null
touch "$DOMAINS"
while IFS= read -r domain; do
  ## Only select partial object keys not actual objects.
  ## These are prepended with PRE and described loosely as "directories"
  if [[ $domain == *" PRE"* ]]; then
    printf "%s\n" "${domain##* }" >> "$DOMAINS"
  fi
done <<< "$ROOT"

while IFS= read -r archive_host; do
  ## Heading for the archive domain + start of archive list
  {
    echo "<h2 class=\"pb-2 border-bottom\">${archive_host::-1}</h2>"
    echo '<ul class="list-group">'
  } >> "$OUTPUT"

  ## Hard remove and create to ensure clean list of archive dates
  ## Redirect output; first run, this file does not exist
  rm "$DOMAIN_ARCHIVES_TEMP" 2> /dev/null
  touch "$DOMAIN_ARCHIVES_TEMP"

  ## read output of AWS S3 list command into
  ## while. Only render lines with PRE
  while IFS= read -r domain_archives; do
    if [[ $domain_archives == *" PRE"* ]]; then
      printf "%s\n" "${domain_archives##* }" >> "$DOMAIN_ARCHIVES_TEMP"
    fi
  done <<< "$(aws s3 ls s3://"${S3_BUCKET_NAME}"/"${archive_host}")"

  ## Manipulate the result, reverse the lines.
  ## This action will order dates in descending order - newest at the top.
  nl "$DOMAIN_ARCHIVES_TEMP" | sort -nr | cut -f 2- > $DOMAIN_ARCHIVES
  ## Remove the temp file
  rm "$DOMAIN_ARCHIVES_TEMP"

  ## Loops over each archive entry, creating an anchor link to each one.
  while IFS= read -r archive_date; do
    readable_date=$(date -d "${archive_date::-6}" +"%A, %d %B %Y")
    {
      echo '<li class="list-group-item">'
      echo "<a href=\"${archive_host}${archive_date}index-2.html\" target=\"_blank\">$readable_date</a>"
      echo '</li>'
    } >> "$OUTPUT"
  done < "$DOMAIN_ARCHIVES"

  echo "</ul>" >> "$OUTPUT"
done < "$DOMAINS"

echo "</div>" >> "$OUTPUT"

{
  echo '</main>'
  echo '</body>'
  echo '</html>'
} >> "$OUTPUT"

## Clean up; prevents s3sync from pushing up to archive
rm "$DOMAINS"
rm "$DOMAIN_ARCHIVES"

## a little pause before any other action takes place
sleep 1
exit 0
