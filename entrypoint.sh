#!/bin/bash
# <!--alex disable black-->

set -eu # Increase bash strictness
set -o pipefail

if [[ -n "${GITHUB_WORKSPACE}" ]]; then
  cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit
fi

export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"

# Run black with reviewdog
black_exit_val="0"
reviewdog_exit_val="0"
if [[ "${INPUT_REPORTER}" = 'github-pr-review' ]]; then
  echo "[action-black] Checking python code with the black formatter and reviewdog..."
  black_check_output="$(black --diff --quiet --check . ${INPUT_BLACK_ARGS})" ||
    black_exit_val="$?"

  # Intput black formatter output to reviewdog
  echo "${black_check_output}" | reviewdog -f="diff" \
    -f.diff.strip=0 \
    -name="${INPUT_TOOL_NAME}" \
    -reporter="github-pr-review" \
    -filter-mode="diff_context" \
    -level="${INPUT_LEVEL}" \
    -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
    ${INPUT_REVIEWDOG_FLAGS} || reviewdog_exit_val="$?"
else

  echo "[action-black] Checking python code with the black formatter and reviewdog..."
  black_check_output="$(black --check . ${INPUT_BLACK_ARGS} 2>&1)" ||
    black_exit_val="$?"

  # Intput black formatter output to reviewdog
  echo "${black_check_output}" | reviewdog -f="black" \
    -name="${INPUT_TOOL_NAME}" \
    -reporter="${INPUT_REPORTER}" \
    -filter-mode="${INPUT_FILTER_MODE}" \
    -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
    -level="${INPUT_LEVEL}" \
    ${INPUT_REVIEWDOG_FLAGS} || reviewdog_exit_val="$?"
fi

# Throw error if an error occurred and fail_on_error is true
if [[ "${INPUT_FAIL_ON_ERROR}" = 'true' && ("${black_exit_val}" -ne '0' || \
  "${reviewdog_exit_val}" -eq "1") ]]; then
  if [[ "${black_exit_val}" -eq "123" ]]; then
    # NOTE: Done since syntax errors are already handled by reviewdog (see
    # https://github.com/reviewdog/errorformat/commit/de0c436afead631a6e3a91ab3da71c16e69e2b9e)
    echo "[action-black] ERROR: Black found a syntax error when checking the" \
      "files (error code: ${black_exit_val})."
    if [[ "${reviewdog_exit_val}" -eq '1' ]]; then
      exit 1
    fi
  else
    exit 1
  fi
fi
