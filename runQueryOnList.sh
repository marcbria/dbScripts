#!/bin/bash
# =============================================================================
# Script: runQueryForAllJournals.sh
# Author: Marc Bria Ramirez
# License: GPL
# =============================================================================
# Description:
#   Executes a SQL query for multiple OJS journals running in Docker containers.
#   Reads a list of journal tags, loads environment variables for each journal,
#   executes the query in the MySQL container, and saves the output to TSV files.
#
# Parameters:
#   sqlQueryFile      : Path to the SQL file containing the query to execute.
#   journalsListFile  : Path to a text file with one journal tag per line.
#   singleFile        : (Optional) If set to 1, generates a single TSV file
#                       with all results, adding a forced "journal" column.
#                       On query errors, a line with "Error" in all data columns
#                       is added for the affected journal.
#                       Otherwise, creates one file per journal without extra column.
# =============================================================================

# =======================
# Constants
# =======================
SITES_BASE_DIR="/home/docker/sites"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"   # Absolute path of script directory
OUTPUT_DIR="${SCRIPT_DIR}/outputs"

# =======================
# Functions
# =======================
checkArguments() {
    if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
        echo "Usage: $0 <sqlQueryFile> <journalsListFile> [singleFile]"
        echo "  singleFile : (optional) 1 to generate a single combined file with a 'journal' column"
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

# Ejecuta la query para un journal y maneja la salida según el modo singleFile
executeQueryForJournal() {
    local journalTag="$1"
    local sqlFile="$2"
    local singleFile="$3"

    local siteDir="$SITES_BASE_DIR/$journalTag"
    local envFile="$siteDir/.env"
    local sqlFilePath="$SCRIPT_DIR/$sqlFile"

    if [ ! -d "$siteDir" ]; then
        echo "❌ Directory $siteDir does not exist. Skipping $journalTag." >&2
        return 1
    fi

    if [ ! -f "$envFile" ]; then
        echo "❌ Env file $envFile not found. Skipping $journalTag." >&2
        return 1
    fi

    if [ ! -f "$sqlFilePath" ]; then
        echo "❌ SQL file $sqlFilePath does not exist. Skipping $journalTag." >&2
        return 1
    fi

    export $(grep -v '^#' "$envFile" | xargs)

    cd "$siteDir" || return 1

    if [ "$singleFile" = "1" ]; then
        # Modo combinado: capturar stdout y stderr por separado
        local stdout_temp=$(mktemp -p "$OUTPUT_DIR" ".tmp_${journalTag}_XXX.tsv")
        local stderr_temp=$(mktemp -p "$OUTPUT_DIR" ".tmp_${journalTag}_err_XXX.txt")

        docker compose exec -T db sh -c \
            "mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -D$MYSQL_DATABASE" \
            < "$sqlFilePath" > "$stdout_temp" 2> "$stderr_temp"
        local status=$?

        if [ $status -ne 0 ]; then
            echo "❌ Error executing query for $journalTag:" >&2
            cat "$stderr_temp" >&2
            rm -f "$stdout_temp" "$stderr_temp"
            return 1
        else
            # Éxito: devolvemos la ruta del archivo temporal con stdout
            rm -f "$stderr_temp"
            echo "$stdout_temp"
            return 0
        fi
    else
        # Modo clásico: un archivo por journal con stdout+stderr combinados
        local timestamp
        timestamp=$(date +%Y%m%d-%H%M)
        local outputFile="$OUTPUT_DIR/${timestamp}-${journalTag}.tsv"
        mkdir -p "$OUTPUT_DIR"

        docker compose exec -T db sh -c \
            "mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -D$MYSQL_DATABASE" \
            < "$sqlFilePath" > "$outputFile" 2>&1
        local status=$?

        if [ $status -eq 0 ]; then
            echo "✅ Query executed successfully for $journalTag"
        else
            echo "❌ Error executing query for $journalTag (details saved in $outputFile)" >&2
            return 1
        fi
        return 0
    fi
}

runQueryForAllJournals() {
    local sqlFile="$1"
    local singleFile="$2"
    local errors=0
    local combinedFile=""
    local header_defined=false
    local original_columns=0

    if [ "$singleFile" = "1" ]; then
        local timestamp
        timestamp=$(date +%Y%m%d-%H%M)
        combinedFile="$OUTPUT_DIR/combined_${timestamp}.tsv"
        mkdir -p "$OUTPUT_DIR"
        > "$combinedFile"
        echo "📦 Modo combinado: se generará $combinedFile"
    fi

    for journalTag in "${journalTags[@]}"; do
        if [ "$singleFile" = "1" ]; then
            # Obtener archivo temporal con stdout del journal (si tiene éxito)
            stdout_temp=$(executeQueryForJournal "$journalTag" "$sqlFile" "1")
            if [ $? -eq 0 ] && [ -n "$stdout_temp" ]; then
                # Journal ejecutado correctamente
                if ! $header_defined; then
                    # Primer journal exitoso: establecer cabecera y número de columnas
                    header_defined=true
                    # Obtener número de columnas de la cabecera original (sin journal)
                    original_columns=$(head -n1 "$stdout_temp" | awk '{print NF; exit}')
                    # Añadir cabecera con "journal" al archivo combinado
                    echo -e "journal\t$(head -n1 "$stdout_temp")" > "$combinedFile"
                    # Añadir datos (omitir la cabecera del archivo temporal)
                    tail -n +2 "$stdout_temp" | awk -v tag="$journalTag" -v OFS='\t' '{print tag, $0}' >> "$combinedFile"
                else
                    # Journals siguientes: añadir datos sin cabecera
                    tail -n +2 "$stdout_temp" | awk -v tag="$journalTag" -v OFS='\t' '{print tag, $0}' >> "$combinedFile"
                fi
                rm -f "$stdout_temp"
                echo "✅ Datos de $journalTag añadidos al archivo combinado"
            else
                # Error en la ejecución del journal
                if $header_defined; then
                    # Ya tenemos la estructura de columnas, podemos añadir línea de error
                    # Generar una línea con el journalTag y "Error" repetido original_columns veces
                    # Construimos la parte de "Error" separada por tabuladores
                    local error_line="$journalTag"
                    for ((i=1; i<=original_columns; i++)); do
                        error_line+=$'\tError'
                    done
                    echo "$error_line" >> "$combinedFile"
                    echo "⚠️ Línea de error añadida para $journalTag (consulta fallida)"
                else
                    echo "⚠️ No se pudo añadir línea de error para $journalTag porque aún no hay cabecera definida." >&2
                fi
                errors=$((errors+1))
            fi
        else
            # Modo clásico: ejecutar y si falla, contar error
            executeQueryForJournal "$journalTag" "$sqlFile" "0" || errors=$((errors+1))
        fi
    done

    if [ "$singleFile" = "1" ]; then
        if ! $header_defined; then
            echo "⚠️ No se pudo procesar ningún journal correctamente. No se generó archivo combinado." >&2
            rm -f "$combinedFile"
        else
            echo "✅ Archivo combinado generado: $combinedFile"
        fi
    fi

    if [ $errors -eq 0 ]; then
        echo "✅ Todos los journals procesados correctamente."
    else
        echo "⚠️ Procesamiento completado con $errors errores."
    fi

    return $errors
}

# =======================
# Main script
# =======================
checkArguments "$@"

sqlQueryFile="$1"
journalsListFile="$2"
singleFile="${3:-0}"   # Por defecto 0 (un archivo por journal)

readJournalsList "$journalsListFile"
runQueryForAllJournals "$sqlQueryFile" "$singleFile"

exit $?
