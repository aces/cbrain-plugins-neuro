#!/bin/bash

# Check all descriptors using both 'jq' and 'bosh validate'

cd boutiques_descriptors || exit 2
maxerror=0
for json in *.json ; do
  echo "Checking $json"

  jq < $json >/dev/null
  jq_status=$?

  bosh validate $json
  bosh_status=$?

  if test $jq_status -eq 0 -a $bosh_status -eq 0 ; then
    # echo " -> passed"
    continue
  else
    echo " -> failed: JQ status=$jq_status ; BOSH status=$bosh_status"
  fi

  if test $jq_status -gt $maxerror ; then
    maxerror=$jq_status
  fi

  if test $bosh_status -gt $maxerror ; then
    maxerror=$bosh_status
  fi

done

exit $maxerror
