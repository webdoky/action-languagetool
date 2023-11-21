#!/bin/sh
set -eo pipefail

API_ENDPOINT="${INPUT_CUSTOM_API_ENDPOINT}"
if [ -z "${INPUT_CUSTOM_API_ENDPOINT}" ]; then
  API_ENDPOINT=http://localhost:8010
  java -cp "/LanguageTool/languagetool-server.jar" org.languagetool.server.HTTPServer --port 8010 &
  echo "Wait the server startup for ${INPUT_WAIT_SERVER_STARTUP_DURATION}s"
  sleep "${INPUT_WAIT_SERVER_STARTUP_DURATION}" # Wait the server startup.
fi

echo "API ENDPOINT: ${API_ENDPOINT}" >&2

if [ -n "${GITHUB_WORKSPACE}" ]; then
  cd "${GITHUB_WORKSPACE}" || exit
fi

git config --global --add safe.directory $GITHUB_WORKSPACE

# https://languagetool.org/http-api/swagger-ui/#!/default/post_check
DATA="language=${INPUT_LANGUAGE}"
if [ -n "${INPUT_ENABLED_RULES}" ]; then
  DATA="$DATA&enabledRules=${INPUT_ENABLED_RULES}"
fi
if [ -n "${INPUT_DISABLED_RULES}" ]; then
  DATA="$DATA&disabledRules=${INPUT_DISABLED_RULES}"
fi
if [ -n "${INPUT_ENABLED_CATEGORIES}" ]; then
  DATA="$DATA&enabledCategories=${INPUT_ENABLED_CATEGORIES}"
fi
if [ -n "${INPUT_DISABLED_CATEGORIES}" ]; then
  DATA="$DATA&disabledCategories=${INPUT_DISABLED_CATEGORIES}"
fi
if [ -n "${INPUT_ENABLED_ONLY}" ]; then
  DATA="$DATA&enabledOnly=${INPUT_ENABLED_ONLY}"
fi

# Disable glob to handle glob patterns with ghglob command instead of with shell.
FILES="${INPUT_PATTERNS}"

run_langtool() {
  for FILE in ${FILES}; do
    echo "Checking ${FILE}..." >&2
    curl --silent \
      --request POST \
      --data "${DATA}" \
      --data-urlencode "text=$(cat "${FILE}")" \
      "${API_ENDPOINT}/v2/check" |
      # replace .txt in file name with .md
      FILE="$(echo $FILE | sed 's/\.txt/\.md/')" tmpl /langtool.tmpl
  done
}

export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"

run_langtool |
  reviewdog -efm="%A%f:%l:%c: %m" -efm="%C %m" -name="LanguageTool" -reporter="${INPUT_REPORTER:-github-pr-check}" -level="${INPUT_LEVEL}"
