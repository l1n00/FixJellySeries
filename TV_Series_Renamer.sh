#!/bin/bash

# --- CONFIGURATION (MODIFY HERE) ---
# Base directory containing all series folders (e.g. black-mirror, dark, etc.)
# If not specified, user will be prompted or current directory will be used.
BASE_DIR=""

# Set to 'true' to simulate changes without actually applying them.
# SET TO 'false' ONLY WHEN YOU ARE SURE IT WORKS!
DRY_RUN=true

# Set to 'true' to delete temporary folders like "_tmp".
# These folders are often download residues and not useful for Jellyfin.
DELETE_TMP_FOLDERS=true

# Video file extensions to consider (add other formats if needed)
VIDEO_EXTENSIONS="mp4 mkv avi mov wmv flv webm m4v"

# Set to 'true' to show more details during processing
VERBOSE=true
# --- END CONFIGURATION ---

# Colors for more readable output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions for colored logs
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to format numbers to two digits (e.g. 1 -> 01)
format_number() {
    printf "%02d" "$((10#$1))"
}

# Function to clean and format series name
clean_series_name() {
    local name="$1"
    # Replace hyphens and underscores with spaces
    name=$(echo "$name" | sed 's/[-_]/ /g')
    # Capitalize each word
    name=$(echo "$name" | sed 's/\b./\u&/g')
    echo "$name"
}

# Function to clean episode title
clean_episode_title() {
    local title="$1"
    # Remove leading and trailing separator characters
    title=$(echo "$title" | sed 's/^[[:space:]_.-]*//; s/[[:space:]_.-]*$//')
    # Replace underscores with spaces
    title=$(echo "$title" | sed 's/_/ /g')
    echo "$title"
}

# Determine working directory
if [ -z "$BASE_DIR" ]; then
    echo "--------------------------------------------------------"
    echo "  TV Series Renamer Script for Jellyfin"
    echo "--------------------------------------------------------"
    echo "Current directory: $(pwd)"
    echo ""
    read -p "Use current directory? [y/N]: " use_current
    if [[ "$use_current" =~ ^[Yy]$ ]]; then
        BASE_DIR="$(pwd)"
    else
        read -p "Enter the path to the series directory: " BASE_DIR
        # Remove any leading and trailing spaces
        BASE_DIR=$(echo "$BASE_DIR" | xargs)
        # Expand path if it contains ~
        BASE_DIR="${BASE_DIR/#\~/$HOME}"
        
        if [ ! -d "$BASE_DIR" ]; then
            log_error "Directory '$BASE_DIR' does not exist."
            exit 1
        fi
        
        # Check if directory contains series folders
        if [ -z "$(find "$BASE_DIR" -maxdepth 1 -type d ! -name ".*" | head -2 | tail -1)" ]; then
            log_warning "Directory '$BASE_DIR' appears empty or contains no subfolders."
            read -p "Continue anyway? [y/N]: " continue_anyway
            if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
                echo "Operation cancelled."
                exit 1
            fi
        fi
        
        cd "$BASE_DIR" || { log_error "Unable to access directory '$BASE_DIR'"; exit 1; }
    fi
fi

echo "--------------------------------------------------------"
echo "  TV Series Renamer Script for Jellyfin"
echo "--------------------------------------------------------"
log_info "Working directory: $BASE_DIR"
log_info "DRY_RUN mode: ${DRY_RUN}"
log_info "Delete _tmp folders: ${DELETE_TMP_FOLDERS}"
log_info "Verbose mode: ${VERBOSE}"
echo "--------------------------------------------------------"

# Function to show series selection menu
show_series_menu() {
    echo "Available series:"
    echo "0) Process ALL series"
    
    local counter=1
    local series_list=()
    
    for series_dir in */; do
        [[ "$series_dir" == "rename_episodes.sh/" ]] && continue
        [[ ! -d "$series_dir" ]] && continue
        
        series_list+=("$series_dir")
        echo "${counter}) $(basename "$series_dir")"
        ((counter++))
    done
    
    echo ""
    read -p "Select the number of the series to process: " choice
    
    if [[ "$choice" == "0" ]]; then
        log_info "Processing ALL series..."
        return 0
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$counter" ]; then
        SELECTED_SERIES="${series_list[$((choice-1))]}"
        log_info "Selected series: $(basename "$SELECTED_SERIES")"
        return 1
    else
        log_error "Invalid selection. Exiting."
        exit 1
    fi
}

# Function to rename season folders
rename_season_folder() {
    local season_dir="$1"
    local series_dir="$2"
    
    SEASON_NAME_RAW=$(basename "$season_dir")
    
    # Extract season number from various formats
    if [[ "$SEASON_NAME_RAW" =~ ^S([0-9]+)$ ]]; then
        SEASON_NUM="${BASH_REMATCH[1]}"
    elif [[ "$SEASON_NAME_RAW" =~ ^Season[[:space:]]*([0-9]+)$ ]]; then
        SEASON_NUM="${BASH_REMATCH[1]}"
    elif [[ "$SEASON_NAME_RAW" =~ ^Stagione[[:space:]]*([0-9]+)$ ]]; then
        SEASON_NUM="${BASH_REMATCH[1]}"
    else
        log_warning "Unrecognized season format: $SEASON_NAME_RAW" >&2
        echo "$season_dir" # Return original path
        return
    fi
    
    FORMATTED_SEASON_NUM=$(format_number "$SEASON_NUM")
    NEW_SEASON_DIR="${series_dir}Season ${FORMATTED_SEASON_NUM}"
    
    if [ "$season_dir" != "$NEW_SEASON_DIR" ]; then
        if $VERBOSE; then
            log_info "Renaming season folder: $(basename "$season_dir") → Season ${FORMATTED_SEASON_NUM}" >&2
        fi
        
        if $DRY_RUN; then
            echo "    DRY-RUN: mv \"$season_dir\" \"$NEW_SEASON_DIR\"" >&2
        else
            if mv "$season_dir" "$NEW_SEASON_DIR" 2>/dev/null; then
                log_success "Season folder renamed" >&2
            else
                log_error "Unable to rename folder: $season_dir" >&2
                echo "$season_dir" # Return original path on error
                return
            fi
        fi
        echo "$NEW_SEASON_DIR" # Return new path
    else
        echo "$season_dir" # Return original path if no rename needed
    fi
}

# Function to rename episode files
rename_episode_files() {
    local season_dir="$1"
    local series_name="$2"
    local formatted_season_num="$3"
    
    local files_processed=0
    
    # Loop through each video file in the season folder
    for ext in $VIDEO_EXTENSIONS; do
        for file in "${season_dir}/"*."$ext"; do
            [[ ! -f "$file" ]] && continue
            
            FILENAME_RAW=$(basename "$file")
            
            # Extract episode number from various formats
            EP_NUM=""
            EP_TITLE=""
            
            if [[ "$FILENAME_RAW" =~ ^E([0-9]+)_(.*)\.${ext}$ ]]; then
                # Format: E01_Title.mp4
                EP_NUM="${BASH_REMATCH[1]}"
                EP_TITLE="${BASH_REMATCH[2]}"
            elif [[ "$FILENAME_RAW" =~ ^E([0-9]+)[[:space:]]+(.*)\.${ext}$ ]]; then
                # Format: E01 Title.mp4
                EP_NUM="${BASH_REMATCH[1]}"
                EP_TITLE="${BASH_REMATCH[2]}"
            elif [[ "$FILENAME_RAW" =~ ^E([0-9]+)-(.*)\.${ext}$ ]]; then
                # Format: E01-Title.mp4
                EP_NUM="${BASH_REMATCH[1]}"
                EP_TITLE="${BASH_REMATCH[2]}"
            elif [[ "$FILENAME_RAW" =~ ^([0-9]+)x([0-9]+)[[:space:]_-]+(.*)\.${ext}$ ]]; then
                # Format: 1x01_Title.mp4
                EP_NUM="${BASH_REMATCH[2]}"
                EP_TITLE="${BASH_REMATCH[3]}"
            elif [[ "$FILENAME_RAW" =~ ^S[0-9]+E([0-9]+)[[:space:]_-]+(.*)\.${ext}$ ]]; then
                # Format: S01E01_Title.mp4
                EP_NUM="${BASH_REMATCH[1]}"
                EP_TITLE="${BASH_REMATCH[2]}"
            elif [[ "$FILENAME_RAW" =~ ^([0-9]+)[[:space:]_.-]+(.*)\.${ext}$ ]]; then
                # Format: 01_Title.mp4
                EP_NUM="${BASH_REMATCH[1]}"
                EP_TITLE="${BASH_REMATCH[2]}"
            else
                if $VERBOSE; then
                    log_warning "Unrecognized pattern for file: $FILENAME_RAW"
                fi
                continue # Skip files that don't follow a recognizable pattern
            fi
            
            # If we found an episode number, proceed
            if [[ -n "$EP_NUM" ]]; then
                FORMATTED_EP_NUM=$(format_number "$EP_NUM")
                
                # Clean the title
                EP_TITLE=$(clean_episode_title "$EP_TITLE")
                
                if $VERBOSE; then
                    log_info "Found episode: EP=${EP_NUM} → ${FORMATTED_EP_NUM}, TITLE='${EP_TITLE}'"
                fi
                
                # Build the new filename
                NEW_FILENAME="${series_name} - s${formatted_season_num}e${FORMATTED_EP_NUM} - ${EP_TITLE}.${ext}"
                NEW_FULL_PATH="${season_dir}/${NEW_FILENAME}"
                
                if [ "$file" != "$NEW_FULL_PATH" ]; then
                    if $VERBOSE; then
                        log_info "Renaming: $(basename "$file") → $(basename "$NEW_FILENAME")"
                    fi
                    
                    if $DRY_RUN; then
                        echo "    DRY-RUN: mv \"$file\" \"$NEW_FULL_PATH\""
                    else
                        if mv "$file" "$NEW_FULL_PATH" 2>/dev/null; then
                            log_success "Episode file renamed"
                        else
                            log_error "Unable to rename file: $file"
                        fi
                    fi
                    ((files_processed++))
                fi
            fi
        done
    done
    
    return $files_processed
}

# Show menu and handle selection
show_series_menu
PROCESS_ALL=$?

# If a specific series was selected, create a list with only that series
if [ $PROCESS_ALL -eq 1 ]; then
    SERIES_TO_PROCESS=("$SELECTED_SERIES")
else
    # Create array with all series
    SERIES_TO_PROCESS=()
    for series_dir in */; do
        [[ "$series_dir" == "rename_episodes.sh/" ]] && continue
        [[ ! -d "$series_dir" ]] && continue
        SERIES_TO_PROCESS+=("$series_dir")
    done
fi

# Counters for statistics
TOTAL_SERIES=0
TOTAL_SEASONS=0
TOTAL_EPISODES=0

# Loop through selected series
for series_dir in "${SERIES_TO_PROCESS[@]}"; do
    SERIES_NAME_RAW=$(basename "$series_dir")
    SERIES_NAME=$(clean_series_name "$SERIES_NAME_RAW")
    
    echo ""
    echo "========================================================"
    log_info "Processing Series: ${SERIES_NAME_RAW} → \"${SERIES_NAME}\""
    echo "========================================================"
    
    ((TOTAL_SERIES++))
    season_count=0
    episode_count=0
    
    # Find all folders that could be seasons
    for season_dir in "${series_dir}"S[0-9]* "${series_dir}"Season* "${series_dir}"Stagione*; do
        [[ ! -d "$season_dir" ]] && continue
        
        if $VERBOSE; then
            log_info "Found season folder: $season_dir"
        fi
        
        ((season_count++))
        ((TOTAL_SEASONS++))
        
        # Rename the season folder
        new_season_dir=$(rename_season_folder "$season_dir" "$series_dir")
        
        if $VERBOSE; then
            log_info "Season folder after rename: $new_season_dir"
        fi
        
        # Extract formatted season number for files
        SEASON_NAME_NEW=$(basename "$new_season_dir")
        if [[ "$SEASON_NAME_NEW" =~ Season[[:space:]]*([0-9]+) ]]; then
            FORMATTED_SEASON_NUM=$(format_number "${BASH_REMATCH[1]}")
        else
            log_warning "Cannot extract season number from: $SEASON_NAME_NEW"
            continue
        fi
        
        # In DRY_RUN mode, use original folder for debug and processing
        if $DRY_RUN; then
            working_dir="$season_dir"
        else
            working_dir="$new_season_dir"
        fi
        
        if $VERBOSE; then
            log_info "Formatted season number: $FORMATTED_SEASON_NUM"
            log_info "Looking for video files in: $working_dir"
            log_info "Folder contents:"
            ls -la "$working_dir" | head -5
        fi
        
        # Rename episode files
        rename_episode_files "$working_dir" "$SERIES_NAME" "$FORMATTED_SEASON_NUM"
        files_renamed=$?
        episode_count=$((episode_count + files_renamed))
        TOTAL_EPISODES=$((TOTAL_EPISODES + files_renamed))
        
        # Delete temporary "_tmp" folders inside the season
        if $DELETE_TMP_FOLDERS; then
            for tmp_dir in "${working_dir}/"*_tmp "${working_dir}/"*tmp*; do
                if [ -d "$tmp_dir" ]; then
                    if $DRY_RUN; then
                        echo "    DRY-RUN: rm -rf \"$tmp_dir\""
                    else
                        if rm -rf "$tmp_dir" 2>/dev/null; then
                            log_success "Deleted temporary folder: $(basename "$tmp_dir")"
                        else
                            log_warning "Unable to delete temporary folder: $tmp_dir"
                        fi
                    fi
                fi
            done
        fi
    done
    
    echo "--------------------------------------------------------"
    log_success "Completed series \"${SERIES_NAME}\" - ${season_count} seasons, ${episode_count} episodes processed"
done

echo ""
echo "========================================================"
echo "                  FINAL SUMMARY"
echo "========================================================"
log_success "Script completed!"
log_info "Series processed: ${TOTAL_SERIES}"
log_info "Seasons processed: ${TOTAL_SEASONS}"
log_info "Episodes processed: ${TOTAL_EPISODES}"

if $DRY_RUN; then
    echo ""
    log_warning "This was a SIMULATION (DRY_RUN=true)."
    log_warning "No files were actually modified."
    echo ""
    echo "To apply real changes:"
    echo "1. Open the script and change DRY_RUN=false"
    echo "2. Run the script again"
else
    echo ""
    log_success "Changes applied successfully!"
    echo ""
    echo "Next steps for Jellyfin:"
    echo "1. Dashboard → Libraries"
    echo "2. Select your TV Series library"
    echo "3. Click the three dots → Refresh metadata"
    echo "4. Select 'Replace all metadata'"
fi

echo "========================================================"