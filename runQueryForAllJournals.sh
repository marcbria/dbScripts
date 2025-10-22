#!/bin/bash
# =============================================================================
# Script: runQueryForAllJournals.sh
# Author: Marc Bria Ramirez
# License: GPL
# =============================================================================
# Description:
#   Executes a SQL query for multiple OJS journals running in Docker containers.
#   Reads a list of journal tags, loads environment variables for each journal,
#   executes the query in the MySQL container, and saves the output to CSV files.
# =============================================================================

# =======================
# Constants
# =======================
OUTPUT_DIR="/home/docker/scripts/DB/outputs"
SITES_BASE_DIR="/home/docker/sites"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"   # Absolute path of script directory

# =======================
# Functions
# =======================
checkArguments() {
    if [ "$#" -ne 2 ]; then
        echo "Usage: $0 <sqlQueryFile> <journalsListFile>"
        exit 1
    fi
}

readJournalsList() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "❌ Journals list file $file does not exist"
        exit 1
    fi
    mapfile -t journalTags < "$file"
}

executeQueryForJournal() {
    local journalTag="$1"
    local sqlFile="$2"

    local siteDir="$SITES_BASE_DIR/$journalTag"
    local envFile="$siteDir/.env"
    local sqlFilePath="$SCRIPT_DIR/$sqlFile"  # Always absolute

    if [ ! -d "$siteDir" ]; then
        echo "❌ Directory $siteDir does not exist. Skipping $journalTag."
        return 1
    fi

    if [ ! -f "$envFile" ]; then
        echo "❌ Env file $envFile not found. Skipping $journalTag."
        return 1
    fi

    if [ ! -f "$sqlFilePath" ]; then
        echo "❌ SQL file $sqlFilePath does not exist. Skipping $journalTag."
        return 1
    fi

    export $(grep -v '^#' "$envFile" | xargs)

    cd "$siteDir" || return 1

    local timestamp
    timestamp=$(date +%Y%m%d-%H%M)
    local outputFile="$OUTPUT_DIR/${timestamp}-${journalTag}.csv"

    mkdir -p "$OUTPUT_DIR"

    docker compose exec -T db sh -c \
        "mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -D$MYSQL_DATABASE" \
        < "$sqlFilePath" > "$outputFile" 2>/dev/null

    if [ "${PIPESTATUS[0]}" -eq 0 ]; then
        echo "✅ Query executed successfully for $journalTag"
    else
        echo "❌ Error executing query for $journalTag"
        return 1
    fi
}

runQueryForAllJournals() {
    local sqlFile="$1"
    local errors=0

    for journalTag in "${journalTags[@]}"; do
        executeQueryForJournal "$journalTag" "$sqlFile" || errors=$((errors+1))
    done

    if [ $errors -eq 0 ]; then
        echo "✅ All journals processed successfully."
    else
        echo "⚠️ Completed with $errors errors."
    fi

    return $errors
}

# =======================
# Main script
# =======================
checkArguments "$@"

sqlQueryFile="$1"
journalsListFile="$2"

readJournalsList "$journalsListFile"
runQueryForAllJournals "$sqlQueryFile"

exit $?  # Returns 0 if all OK, >0 if any error occurred

