#!/bin/bash

ROOT=$(aws s3 ls s3://"${S3_BUCKET_NAME}"/)
OUTPUT="/archiver/snapshots/index.html"

{
  echo "<!doctype html><html lang=\"en\"><head><title>Justice Archive Index</title>"
  echo '<style>main{display:block}a{background-color:transparent;color:#337ab7;text-decoration:none}.list-group-item,body{background-color:#fff}a:active,a:hover{outline:0}h1{font-size:2em;margin:.67em 0}*,:after,:before{-webkit-box-sizing:border-box;-moz-box-sizing:border-box;box-sizing:border-box}html{font-family:sans-serif;-ms-text-size-adjust:100%;-webkit-text-size-adjust:100%;font-size:10px;-webkit-tap-highlight-color:transparent}body{margin:0;font-family:"Helvetica Neue",Helvetica,Arial,sans-serif;font-size:14px;line-height:1.42857143;color:#333}a:focus,a:hover{color:#23527c;text-decoration:underline}a:focus{outline:-webkit-focus-ring-color auto 5px;outline-offset:-2px}.container{padding-right:15px;padding-left:15px;margin-right:auto;margin-left:auto}@media (min-width:768px){.container{width:750px}}@media (min-width:992px){.container{width:970px}}@media (min-width:1200px){.container{width:1170px}}.list-group{padding-left:0;margin-bottom:20px}.list-group-item{position:relative;display:block;padding:10px 15px;margin-bottom:-1px;border:1px solid #ddd}.list-group-item:first-child{border-top-left-radius:4px;border-top-right-radius:4px}.list-group-item:last-child{margin-bottom:0;border-bottom-right-radius:4px;border-bottom-left-radius:4px}.container:after,.container:before{display:table;content:" "}.container:after{clear:both}.list-group{border-radius:4px;-webkit-box-shadow:0 1px 2px rgba(0,0,0,.075);box-shadow:0 1px 2px rgba(0,0,0,.075)}</style>'
  echo '</head><body><main>'
} > "$OUTPUT"

echo "<div class=\"container px-4 py-5\"><h1>Ministry of Justice Archiver</h1>" >> "$OUTPUT"
  while IFS= read -r line; do

    web_url="${line##* }"
    if [[ $web_url = \.* ]] ; then
        continue
    fi
    if [[ "$web_url" == index.html ]]; then
        continue
    fi

    {
      echo "<h2 class=\"pb-2 border-bottom\">$web_url</h2>"
      echo "<ul class=\"list-group\">"
    } >> "$OUTPUT"

    while IFS= read -r date_line; do

      if [[ $date_line = \.* ]] ; then
          continue
      fi

      if [[ "$web_url" == index.html ]]; then
          continue
      fi

      date_stamp="${date_line##* }"
      readable_date=$(date -d "${date_stamp::-6}" +"%A, %d %B %Y")
      echo "<li class=\"list-group-item\"><a href=\"${web_url}${date_stamp}index.html\">$readable_date</a></li>" >> "$OUTPUT"
    done <<< "$(aws s3 ls s3://"${S3_BUCKET_NAME}"/"${web_url}")"

    echo "</ul>" >> "$OUTPUT"
  done <<< "$ROOT"

echo "</div>" >> "$OUTPUT"

{
  echo '</main>'
  echo '</body>'
  echo '</html>'
} >> "$OUTPUT"
