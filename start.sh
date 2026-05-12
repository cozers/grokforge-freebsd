#!/bin/sh
set -eu

APP_HOME=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CONFIG_FILE="${APP_HOME}/config.toml"
PID_FILE="${APP_HOME}/run/grokforge.pid"
LOG_FILE="${APP_HOME}/logs/stdout.log"
BINARY="${APP_HOME}/grokforge-freebsd-amd64"
BINARY_NAME=$(basename "${BINARY}")

mkdir -p "${APP_HOME}/run" "${APP_HOME}/logs" "${APP_HOME}/data"

if [ ! -f "${CONFIG_FILE}" ]; then
  echo "ERROR: config.toml not found: ${CONFIG_FILE}"
  exit 1
fi

if [ ! -x "${BINARY}" ]; then
  echo "ERROR: binary not found or not executable: ${BINARY}"
  echo "Run: chmod +x ${BINARY}"
  exit 1
fi

if [ -f "${PID_FILE}" ]; then
  OLD_PID=$(cat "${PID_FILE}" 2>/dev/null || echo "")
  if [ -n "${OLD_PID}" ] && kill -0 "${OLD_PID}" 2>/dev/null; then
    echo "Found existing process (PID: ${OLD_PID}), stopping it..."
    kill "${OLD_PID}" 2>/dev/null || kill -9 "${OLD_PID}" 2>/dev/null || true
    sleep 1
  fi
  rm -f "${PID_FILE}"
fi

if command -v pgrep >/dev/null 2>&1; then
  OLD_PIDS=$(pgrep -f "${BINARY_NAME}" 2>/dev/null || true)
  if [ -n "${OLD_PIDS}" ]; then
    echo "Found stale ${BINARY_NAME} processes, stopping them..."
    for PID in ${OLD_PIDS}; do
      if [ "${PID}" != "$$" ] && kill -0 "${PID}" 2>/dev/null; then
        kill "${PID}" 2>/dev/null || kill -9 "${PID}" 2>/dev/null || true
      fi
    done
    sleep 1
  fi
fi

echo "Starting GrokForge..."
nohup "${BINARY}" -config "${CONFIG_FILE}" >> "${LOG_FILE}" 2>&1 &

NEW_PID=$!
echo "${NEW_PID}" > "${PID_FILE}"

echo "Started successfully"
echo "PID: ${NEW_PID}"
echo "Log: ${LOG_FILE}"
echo "Config: ${CONFIG_FILE}"
