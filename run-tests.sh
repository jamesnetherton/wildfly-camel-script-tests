#!/bin/bash

trap cleanup SIGHUP SIGINT SIGTERM

SCRIPT_NAME=module-checker.groovy
OLDIFS=${IFS}
IFS=$'\n'

function cleanup {
  IFS=${OLDIFS}
}

function runTestScenario {
  local SCENARIO=$1
  local RESOURCE_BASE=src/main/resources/${SCENARIO}
  local MODULE_BASE_DIR=${RESOURCE_BASE}/modules/system/layers

  if [[ -f ${RESOURCE_BASE}/options.txt ]]
  then
    local OPTIONS=$(cat ${RESOURCE_BASE}/options.txt)
  fi

  groovy -Dwildfly.module.dir=${MODULE_BASE_DIR}/base -Dsmartics.module.dir=${MODULE_BASE_DIR}/fuse ${OPTIONS} ${SCRIPT_NAME} 1>&2 > ${SCENARIO}.out

  doAssertions $? ${SCENARIO} ${RESOURCE_BASE}
}

function doAssertions {
  local ACTUAL_EXIT_CODE="$1"
  local SCENARIO=$2
  local RESOURCE_BASE=$3
  local EXPECTED_EXIT_CODE=$(bundle exec jgrep -i ${RESOURCE_BASE}/assert.json -s exitCode)

  printf "\nTEST: ${SCENARIO}\n"

  if [[ "${EXPECTED_EXIT_CODE}" != "${ACTUAL_EXIT_CODE}" ]]
  then
    echo ">>>> Expected exit code ${EXPECTED_EXIT_CODE} but was ${ACTUAL_EXIT_CODE}"
    exit 1
  fi

  for ASSERTION in $(bundle exec jgrep -i ${RESOURCE_BASE}/assert.json -s assertions)
  do
    if ! grep ${ASSERTION} ${SCENARIO}.out > /dev/null
    then
        echo ">>>> Expected output ${ASSERTION}"
        exit 1
    fi
  done

  echo ">>>> PASSED"
}

curl -s ${SCRIPT_SOURCE} > ${SCRIPT_NAME}

if [[ "$?" != "0" ]]
then
  exit 1
fi

if [[ "${EXPECTED_SHA}" == "$(sha1sum module-checker.groovy | cut -f1 -d' ')" ]]
then
  sed -i 's/properties\.get/System.getProperty/g' ${SCRIPT_NAME}
  sed -i 's/properties\.ignoredDependencies/System.getProperty(\"ignoredDependencies\")/g' ${SCRIPT_NAME}
  sed -i 's/fail/System\.exit\(1)/g' ${SCRIPT_NAME}

  printf "\n\nRUNNING TESTS\n"
  runTestScenario duplicate-module
  runTestScenario duplicate-resource
  runTestScenario ignored-dependency
  runTestScenario no-duplicates
else
  echo "Unexpected SHA1 for ${SCRIPT_SOURCE}"
  exit 1
fi
