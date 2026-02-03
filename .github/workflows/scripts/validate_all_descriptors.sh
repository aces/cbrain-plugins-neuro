#!/bin/bash

# Check all descriptors using both 'jq' and 'bosh validate'

cd boutiques_descriptors || exit 2

max_status=0

for json in *.json ; do
  echo ""
  echo "--------------------------------------------"
  echo "Checking $json"
  echo "--------------------------------------------"

  jq '.["name"]' < $json # print the name
  jq_status=$?

  bosh validate $json  # prints "OK"
  bosh_status=$?

  if test $jq_status -eq 0 -a $bosh_status -eq 0 ; then
    # echo " -> passed"
    continue
  fi

  echo " -> failed: JQ status=$jq_status ; BOSH status=$bosh_status"

  if test $jq_status -gt $max_status ; then
    max_status=$jq_status
  fi

  if test $bosh_status -gt $max_status ; then
    max_status=$bosh_status
  fi

done

echo ""
echo "--------------------------------------------"
echo "Final exit code: $max_status"
echo "--------------------------------------------"

exit $max_status
