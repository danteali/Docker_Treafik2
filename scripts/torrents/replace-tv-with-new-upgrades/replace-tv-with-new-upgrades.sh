#!/bin/bash

# Quick script to replace existing media files with newly downloaded files (better versions).
# Save path to new downloads in the DLDIRS array and the path to target paths in the corresponding in TVDIRS.
# The script will loop through both arrays:
#    For each Season.XX folder in the new download...
#        Check new Season.XX is not empty
#        If a corresponding Season.XX exists in TV then delete it.
#        Then move/copy the newly downloaded Season.XX to the TV directory.
#        After move/copy, move source directory to separate location to avoid confusion (see PROCESSEDDIR variable).
# This method helps avoid deleting any folder in the destination if there is not a corresponding folder
# in the source. 
# We previously ended up delteing files we didn't have replaceents for since our original script first
# looped through the destination dirs and deleted all Season.XX folders. And we accidentally ran the
# script a second time after processing failed part way through the first attempt - we deleted destination
# Season.XX folders which had already been moved during first run and lost the upgraded files. 

# May be safer to copy files instead of moving them - set variable 'COPY' to 1 to copy instead of move.

# find /storage/scratchpad/downloads/_torrents/x265-TV-Done -maxdepth 1 -type d | sort
DLDIRS=(
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Black.Doves.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Bloodline.720p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Continuum.720p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Daredevil.Born.Again.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Dark.Matter.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Fargo.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Father.Ted.720p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Five.Came.Back.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Fortitude.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Frank.Lloyd.Wright.400p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Frozen.Planet.2011.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Gavin.and.Stacey.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Get.Shortly.720p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Halt.and.Catch.Fire.720p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/House.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/House.Of.Cards.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Im.Alan.Partridge.720p.x265"
    ##"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Its.Always.Sunny.in.Philadelphia.480p.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Kims.Convenience.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Kin.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Leah.Remini.Scientology.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Letterkenny.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Lewis.and.Clark.The.Journey.of.the.Corps.of.Discovery.720p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Life.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Life.in.Cold.Blood.576p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Life.in.the.Freezer.576p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Life.in.the.Undergrowth.576p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Life.of.Birds.576p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Life.of.Mammals.576p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Madagascar.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Making.A.Murderer.720p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Mare.Of.Easttown.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Marvels.Daredevil.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Marvels.The.Punisher.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Masters.of.the.Air.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Medici.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Mr.Robot.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Narcos.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Nightsleeper.720p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Peaky.Blinders.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Planet.Earth.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Pride.and.Prejudice.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Private.Life.of.Plants.720p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Say.Nothing.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Succession.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Boys.Presents.Diabolical.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Bridge.720p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Civil.War.720p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Fall.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/The.It.Crowd.720p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Langoliers.720p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Last.Of.Us.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Lord.of.the.Rings.The.Rings.of.Power.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Man.in.the.High.Castle.2160p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Mighty.Boosh.576p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/The.National.Parks.America's.Best.Idea.720p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Newsroom.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Office.UK.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Terror.1080p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Untold.History.of.the.United.States.720p.x265"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Young.Pope.720p.x265"
    ##"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Thomas.Jefferson.2025.1080p.AV1"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Bloodlands.720p.x264"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/COBRA.720p.x264"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Extras.720p.x264"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Its.Always.Sunny.in.Philadelphia.480p.x264"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Long.Way.Up.1080p.x264"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Modern.Family.720p.x264"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Stephen.Kings.Nightmares.and.Dreamscapes.720p.x264"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/Stephen.Kings.Rose.Red.540p.x264"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/The.People.Of.Paradise.1960.720p.x264"
    #"/storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Roosevelts.An.Intimate.History.720p.x264"

    "/storage/scratchpad/downloads/_torrents/x265-TV-Done/Boardwalk.Empire.720p.x265"
    "/storage/scratchpad/downloads/_torrents/x265-TV-Done/Forbrydelsen.720p.x265"
    "/storage/scratchpad/downloads/_torrents/x265-TV-Done/Life.on.Earth.1979.720p.x265"
    "/storage/scratchpad/downloads/_torrents/x265-TV-Done/Marvels.Jessica.Jones.720p.x265"
    "/storage/scratchpad/downloads/_torrents/x265-TV-Done/Peep.Show.720p.x265"
    "/storage/scratchpad/downloads/_torrents/x265-TV-Done/Prohibition.720p.x265"
    "/storage/scratchpad/downloads/_torrents/x265-TV-Done/Salems.Lot.720p.x264"
    "/storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Living.Planet.1984.540p.x265"
    "/storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Night.Manager.720p.x265"
    "/storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Trials.of.Life.1990.720p.10bit.BluRay.x265-budgetbits"
    "/storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Vow.720p.x264"
    "/storage/scratchpad/downloads/_torrents/x265-TV-Done/The.X.Files.720p.x264"
    "/storage/scratchpad/downloads/_torrents/x265-TV-Done/Utopia.1080p.x265"
    "/storage/scratchpad/downloads/_torrents/x265-TV-Done/W1A.720p.x265"
    "/storage/scratchpad/downloads/_torrents/x265-TV-Done/Yes.Minister.576p.x264"
    "/storage/scratchpad/downloads/_torrents/x265-TV-Done/Yes.Prime.Minister.576p.x264"
)

TVDIRS=(
    #"/storage/Media/Video/TV/_NOBACKUP/Black.Doves"
    #"/storage/Media/Video/TV/_NOBACKUP/Bloodline"
    #"/storage/Media/Video/TV/_NOBACKUP/Continuum"
    #"/storage/Media/Video/TV/_NOBACKUP/Daredevil.Born.Again"
    #"/storage/Media/Video/TV/_NOBACKUP/Dark.Matter"
    #"/storage/Media/Video/TV/Fargo"
    #"/storage/Media/Video/TV/Father.Ted"
    #"/storage/Media/Video/TV/Five.Came.Back"
    #"/storage/Media/Video/TV/_NOBACKUP/Fortitude"
    #"/storage/Media/Video/TV/Frank.Lloyd.Wright"
    #"/storage/Media/Video/TV/Frozen.Planet.2011"
    #"/storage/Media/Video/TV/Gavin.And.Stacey"
    #"/storage/Media/Video/TV/_NOBACKUP/Get.Shorty"
    #"/storage/Media/Video/TV/_NOBACKUP/Halt.and.Catch.Fire"
    #"/storage/Media/Video/TV/_NOBACKUP/House.MD"
    #"/storage/Media/Video/TV/House.of.Cards"
    #"/storage/Media/Video/TV/Im.Alan.Partridge"
    ##"/storage/Media/Video/TV/Its.Always.Sunny.in.Philadelphia"
    #"/storage/Media/Video/TV/Kims.Convenience"
    #"/storage/Media/Video/TV/_NOBACKUP/Kin"
    #"/storage/Media/Video/TV/_NOBACKUP/Leah.Remini.Scientology.and.the.Aftermath"
    #"/storage/Media/Video/TV/_NOBACKUP/Letterkenny"
    #"/storage/Media/Video/TV/Lewis.and.Clark.The.Journey.of.the.Corps.of.Discovery"
    #"/storage/Media/Video/TV/Life.2009"
    #"/storage/Media/Video/TV/Life.In.Cold.Blood.2008"
    #"/storage/Media/Video/TV/Life.In.The.Freezer.1993"
    #"/storage/Media/Video/TV/Life.In.The.Undergrowth.2005"
    #"/storage/Media/Video/TV/Life.Of.Birds.1998"
    #"/storage/Media/Video/TV/Life.Of.Mammals.2002"
    #"/storage/Media/Video/TV/Madagascar.2011"
    #"/storage/Media/Video/TV/Making.a.Murderer"
    #"/storage/Media/Video/TV/_NOBACKUP/Mare.of.Easttown"
    #"/storage/Media/Video/TV/_NOBACKUP/Marvels.Daredevil"
    #"/storage/Media/Video/TV/Marvels.The.Punisher"
    #"/storage/Media/Video/TV/Masters.of.the.Air"
    #"/storage/Media/Video/TV/Medici.Masters.of.Florence"
    #"/storage/Media/Video/TV/Mr.Robot"
    #"/storage/Media/Video/TV/Narcos"
    #"/storage/Media/Video/TV/_NOBACKUP/Nightsleeper"
    #"/storage/Media/Video/TV/_NOBACKUP/Peaky.Blinders"
    #"/storage/Media/Video/TV/Planet.Earth.2006"
    #"/storage/Media/Video/TV/Pride.and.Prejudice"
    #"/storage/Media/Video/TV/Private.Life.Of.Plants.1995"
    #"/storage/Media/Video/TV/Say.Nothing"
    #"/storage/Media/Video/TV/Succession"
    #"/storage/Media/Video/TV/The.Boys.Presents.Diabolical"
    #"/storage/Media/Video/TV/_NOBACKUP/The.Bridge"
    #"/storage/Media/Video/TV/The.Civil.War"
    #"/storage/Media/Video/TV/The.Fall"
    #"/storage/Media/Video/TV/The.IT.Crowd"
    #"/storage/Media/Video/TV/The.Langoliers"
    #"/storage/Media/Video/TV/Last.of.Us"
    #"/storage/Media/Video/TV/The.Lord.of.the.Rings.The.Rings.of.Power"
    #"/storage/Media/Video/TV/The.Man.in.the.High.Castle"
    #"/storage/Media/Video/TV/The.Mighty.Boosh"
    #"/storage/Media/Video/TV/The.National.Parks.Americas.Best.Idea"
    #"/storage/Media/Video/TV/The.Newsroom"
    #"/storage/Media/Video/TV/The.Office.UK"
    #"/storage/Media/Video/TV/_NOBACKUP/The.Terror"
    #"/storage/Media/Video/TV/The.Untold.History.of.the.United.States"
    #"/storage/Media/Video/TV/The.Young.Pope"
    ##"/storage/Media/Video/TV/_NOBACKUP/Thomas.Jefferson.2025"
    #"/storage/Media/Video/TV/_NOBACKUP/Bloodlands"
    #"/storage/Media/Video/TV/_NOBACKUP/COBRA"
    #"/storage/Media/Video/TV/Extras"
    #"/storage/Media/Video/TV/Its.Always.Sunny.in.Philadelphia"
    #"/storage/Media/Video/TV/Long.Way.Up"
    #"/storage/Media/Video/TV/Modern.Family"
    #"/storage/Media/Video/TV/Stephen.Kings.Nightmares.and.Dreamscapes"
    #"/storage/Media/Video/TV/Stephen.Kings.Rose.Red"
    #"/storage/Media/Video/TV/The.People.Of.Paradise.1960"
    #"/storage/Media/Video/TV/The.Roosevelts.An.Intimate.History" 
    
    "/storage/Media/Video/TV/_NOBACKUP/Boardwalk.Empire"
    "/storage/Media/Video/TV/_NOBACKUP/Forbrydelsen"
    "/storage/Media/Video/TV/Life.On.Earth.1979"
    "/storage/Media/Video/TV/_NOBACKUP/Marvels.Jessica.Jones"
    "/storage/Media/Video/TV/_NOBACKUP/Peep.Show"
    "/storage/Media/Video/TV/Prohibition"
    "/storage/Media/Video/TV/Salems.Lot"
    "/storage/Media/Video/TV/The.Living.Planet.1984"
    "/storage/Media/Video/TV/The.Night.Manager"
    "/storage/Media/Video/TV/The.Trials.Of.Life.1990"
    "/storage/Media/Video/TV/_NOBACKUP/The.Vow"
    "/storage/Media/Video/TV/The.X.Files"
    "/storage/Media/Video/TV/_NOBACKUP/Utopia"
    "/storage/Media/Video/TV/W1A"
    "/storage/Media/Video/TV/Yes.Minister"
    "/storage/Media/Video/TV/Yes.Prime.Minister"   
)

WHEREAMI="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
SCRIPTNAME="$(basename -- "$(test -L "$0" && readlink "$0" || echo "$0")")"
SCRIPTNAME_NOEXT="${SCRIPTNAME%.*}"
LOGFILE="${WHEREAMI}/${SCRIPTNAME_NOEXT}.log"
PROCESSEDDIR="/storage/scratchpad/downloads/_torrents/x265-TV-Done/__PROCESSED"    # After move/copy is complete, move source folder to this directory
COPY=1    # Set to 0 to move source files to target. Set to 1 to copy source files to target


# For ALL exits (incl errors)
function exitcleanup() {
    disablescriptlogging
}

# See trap info:
    # https://phoenixnap.com/kb/bash-trap-command
#trap 'exec 2>&4 1>&3' EXIT
trap 'exitcleanup' EXIT #SIGTERM SIGHUP #ERR #SIGINT

function enablescriptlogging(){
    # Save file descriptors for restoration at exit
    exec 3>&1 4>&2
    # redirect all output to screen and file
    exec > >(tee -ia "${LOGFILE}" ) 2>&1
    SCRIPTLOGGING=1
    #echo "(logging enabled)"
}

function disablescriptlogging() {
    if [[ $SCRIPTLOGGING -eq 1 ]]; then
        # Restore previously saved file descriptors
        exec 1>&3 2>&4
        # If interactive shell restore output
        [[ $- == *i* ]] && exec &>/dev/tty
        SCRIPTLOGGING=0
        #echo "(logging disabled)"; echo
    fi
}

enablescriptlogging

echo "================================================================================"
echo "Executing script at: $(date +%Y%m%d-%H%M%S)"

# Before processing, check that the number of source and target directories is equal
if [[ "${#DLDIRS[@]}" -ne "${#TVDIRS[@]}" ]]; then
    echo "ERROR - Number of source and target directories do not match"
    echo "Exiting script"
    exit 1
else
    echo "Number of source and target directories match: ${#DLDIRS[@]}"
fi

# Before processing, check that the source and target directories exist
missing=0
for i in "${!DLDIRS[@]}"; do
    src="${DLDIRS[$i]}"
    dest="${TVDIRS[$i]}"
    if [ ! -d "$src" ]; then echo "ERROR - Source not found: $src"; missing=1; fi
    if [ ! -d "$dest" ]; then echo "ERROR - Target not found: $dest"; missing=1; fi
done
if [[ "${missing}" -eq 1 ]]; then
    echo "Exiting script"
    exit 1
else
    echo "All source and target directories found, proceeding with script."
fi

# If doing copy confirm that processed directory exists
if [[ $COPY -eq 1 ]]; then
    if [ ! -d "${PROCESSEDDIR}" ]; then
        echo "ERROR - Copying files (not moving) but 'Processed' directory not found: ${PROCESSEDDIR}"
        echo "Exiting script"
        exit 1
    fi
fi

# Ask user if they want to continue with processing, exit script if no answer in 10s?
echo; echo "Continue with processing? (y/n)"
echo "Press 'y' to continue, or 'n' to exit script (script will exit if no response in 10s)"
read -t 10 -n 1 -s answer
if [[ $answer != "y" ]]; then
    echo "Exiting script"
    exit 1
fi


for i in "${!DLDIRS[@]}"; do
    echo "$(date +%Y%m%d-%H%M%S) ----------------------------------------"
    src="${DLDIRS[$i]}"
    dest="${TVDIRS[$i]}"
    echo "Source: $src"
    echo "Target: $dest"
    if [ ! -d "$src" ]; then echo "    ERROR - Source not found: $src"; continue; fi
    if [ ! -d "$dest" ]; then echo "    ERROR - Target not found: $dest"; continue; fi
    # Check for existence of Season.* folders in source
    if ! find "$src" -maxdepth 1 -type d -name "Season.*" | grep -q .; then
        echo "    WARNING - No 'Season' folders found in ${src}, skipping move/copy"
        continue
    fi
    # Loop through the Season.XX folders in the source, delete existing ones in the target, and move the new ones from the source to the target
    for season in "$src"/Season.*; do
        if [ -d "$season" ]; then
            echo "    Processing: ${season} ..."

            # Check if the same Season.XX folder exists in the destination
            if [ -d "$dest/$(basename "$season")" ]; then
                echo "        Found existing $(basename "${season}") folder in target $dest, deleting ..."
                rm -rf "${dest:?}/$(basename "${season:?}")" | sed 's/^/            /'
            else
                echo "        WARNING - No existing $(basename "${season}") folder in target $dest"
            fi

            # Move or copy files to target
            if [[ COPY -eq 1 ]]; then
                echo "        Copying $(basename "${season}") to target $dest ..."
                cp -R "$season" "$dest/" | sed 's/^/            /'
            else
                echo "        Moving $(basename "${season}") to target $dest ..."
                mv "$season" "$dest/" | sed 's/^/            /'
            fi
        fi
    done
    # List any remaining files or folders left in $src - only if COPY=0 or all source files will still exist since none moved.
    if [[ COPY -eq 0 ]]; then
        if [ "$(ls -A "$src")" ]; then
            echo "    WARNING - Source directory still contains files after move:"
            find "$src" -maxdepth 1 -type d | sed 's/^/        /'
        else
            echo "    No remaining files in $src"
        fi
    fi
    
    # Move source folder to '__PROCESSED' subdirectory
    echo "    Moving $src to 'processing completed' subdirectory ..."
    mv "$src" "${PROCESSEDDIR}/" | sed 's/^/        /'
    
done

echo ""
echo "REMEMBER TO REVIEW MOVED FILES AND DELETE DUPLICATE MEDIA FROM THE __PROCESSED FOLDER"
echo ""

# ==================================================================================================
# ORIGINAL CODE
# Flawed as it deleted all Season.XX folders in the destination before moving new ones
# which meant we lost any Season.XX folders in the destination when we acidentally re-ran the script
# after some updated media had already been copied to the target.
# ==================================================================================================
#
## DELETE EXISTING TV SEASON FOLDERS
#echo "DELETEING OLD MEDIA"
#for dir in "${TVDIRS[@]}"; do
#    tvdir="/storage/Media/Video/TV/$dir"
#    if [ -d "$tvdir" ]; then
#        if find "$tvdir" -maxdepth 1 -type d -name "Season.*" | grep -q .; then
#            echo "Deleting 'Season' folders in $tvdir"
#            rm -rf "/storage/Media/Video/TV/$dir/Season."* | tee -a "$ERRORLOG"
#        else
#            echo "No 'Season' folder to delete in ${tvdir}" >> "$ERRORLOG"
#        fi
#    else
#        echo "$tvdir not found"
#    fi
#done
#
## Move new season folders
#echo "MOVING NEW MEDIA TO DESTINATION"
#for i in "${!DLDIRS[@]}"; do
#    src="${DLDIRS[$i]}"
#    dest="/storage/Media/Video/TV/${TVDIRS[$i]}"
#    if [ -d "$src" ]; then
#        if find "$src" -maxdepth 1 -type d -name "Season.*" | grep -q .; then
#            echo "Moving 'Season' folders from $src to $dest"
#            mv "${src}/Season."* "${dest}/" | tee -a "$ERRORLOG"
#        else
#            echo "No 'Season' folders found in ${src}, skipping move" >> "$ERRORLOG"
#        fi
#    else
#        echo "$src not found"
#    fi
#done
# ==================================================================================================


# ==================================================================================================
# FOLDER LISTS - TO MAKE COPY/PASTING INTO ARRAYS ABOVE EASIER
# ==================================================================================================

# find /storage/scratchpad/downloads/_torrents/x265-TV-Done -maxdepth 1 -type d | sort

#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/24.720p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Derry.Girls.720p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Downton.Abbey.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Eureka.720p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Fear.The.Walking.Dead.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Freaks.and.Geeks.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Greys.Anatomy.720p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Lost.720p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Star.Trek.Discovery.720p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Star.Trek.Enterprise.720p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Star.Trek.Picard.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Star.Trek.The.Next.Generation.1080p.AV1.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Star.Trek.The.Original.Series.1080p.AV1
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Star.Trek.Voyager.720p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Star.Wars.Rebels.720p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Star.Wars.The.Bad.Batch.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Stephen.Kings.The.Stand.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Stand.2020.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Thick.Of.It.540p-720p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Vietnam.War.2017.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Walking.Dead.World.Beyond.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Veep.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/We.Own.This.City1080p.x265

#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Black.Doves.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Bloodline.720p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Continuum.720p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Daredevil.Born.Again.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Dark.Matter.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Fargo.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Father.Ted.720p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Five.Came.Back.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Fortitude.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Frank.Lloyd.Wright.400p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Frozen.Planet.2011.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Gavin.and.Stacey.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Get.Shortly.720p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Halt.and.Catch.Fire.720p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/House.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/House.Of.Cards.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Im.Alan.Partridge.720p.x265
#    #/storage/scratchpad/downloads/_torrents/x265-TV-Done/Its.Always.Sunny.in.Philadelphia.480p.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Kims.Convienience.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Kin.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Leah.Remini.Scientology.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Letterkenny.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Lewis.and.Clark.The.Journey.of.the.Corps.of.Discovery.720p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Life.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Life.in.Cold.Blood.576p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Life.in.the.Freezer.576p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Life.in.the.Undergrowth.576p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Life.of.Birds.576p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Life.of.Mammals.576p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Madagascar.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Making.A.Murderer.720p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Mare.Of.Easttown.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Marvels.Daredevil.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Marvels.The.Punisher.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Masters.of.the.Air.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Medici.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Mr.Robot.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Narcos.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Nightsleeper.720p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Peaky.Blinders.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Planet.Earth.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Pride.and.Prejudice.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Private.Life.of.Plants.720p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Say.Nothing.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/Succession.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Boys.Presents.Diabolical.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Bridge.720p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Civil.War.720p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Fall.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.It.Crowd.720p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Langoliers.720p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Last.Of.Us.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Lord.of.the.Rings.The.Rings.of.Power.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Man.in.the.High.Castle.2160p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Mighty.Boosh.576p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.National.Parks.America's.Best.Idea.720p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Newsroom.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Office.UK.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Terror.1080p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Untold.History.of.the.United.States.720p.x265
#    /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Young.Pope.720p.x265
#    #/storage/scratchpad/downloads/_torrents/x265-TV-Done/Thomas.Jefferson.2025.1080p.AV1

#   /storage/scratchpad/downloads/_torrents/x265-TV-Done/Bloodlands.720p.x264
#   /storage/scratchpad/downloads/_torrents/x265-TV-Done/COBRA.720p.x264
#   /storage/scratchpad/downloads/_torrents/x265-TV-Done/Extras.720p.x264
#   /storage/scratchpad/downloads/_torrents/x265-TV-Done/Its.Always.Sunny.in.Philadelphia.480p.x264
#   /storage/scratchpad/downloads/_torrents/x265-TV-Done/Long.Way.Up.1080p.x264
#   /storage/scratchpad/downloads/_torrents/x265-TV-Done/Modern.Family.720p.x264
#   /storage/scratchpad/downloads/_torrents/x265-TV-Done/Stephen.Kings.Nightmares.and.Dreamscapes.720p.x264
#   /storage/scratchpad/downloads/_torrents/x265-TV-Done/Stephen.Kings.Rose.Red.540p.x264
#   /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.People.Of.Paradise.1960.720p.x264
#   /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Roosevelts.An.Intimate.History.720p.x264

#   /storage/scratchpad/downloads/_torrents/x265-TV-Done/Boardwalk.Empire.720p.x265
#   /storage/scratchpad/downloads/_torrents/x265-TV-Done/Life.on.Earth.1979.720p.x265
#   /storage/scratchpad/downloads/_torrents/x265-TV-Done/Marvels.Jessica.Jones.720p.x265
#   /storage/scratchpad/downloads/_torrents/x265-TV-Done/Peep.Show.720p.x265
#   /storage/scratchpad/downloads/_torrents/x265-TV-Done/__PROCESSED
#   /storage/scratchpad/downloads/_torrents/x265-TV-Done/Prohibition.720p.x265
#   /storage/scratchpad/downloads/_torrents/x265-TV-Done/Salems.Lot.720p.x264
#   /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Living.Planet.1984.540p.x265
#   /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Night.Manager.720p.x265
#   /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Trials.of.Life.1990.720p.10bit.BluRay.x265-budgetbits
#   /storage/scratchpad/downloads/_torrents/x265-TV-Done/The.Vow.720p.x264
#   /storage/scratchpad/downloads/_torrents/x265-TV-Done/Utopia.1080p.x265
#   /storage/scratchpad/downloads/_torrents/x265-TV-Done/W1A.720p.x265
#   /storage/scratchpad/downloads/_torrents/x265-TV-Done/Yes.Minister.576p.x264
#   /storage/scratchpad/downloads/_torrents/x265-TV-Done/Yes.Prime.Minister.576p.x264

# ==================================================================================================

# find /storage/Media/Video/TV -maxdepth 1 -type d | sort; \
# find /storage/Media/Video/TV/_NOBACKUP -maxdepth 1 -type d | sort; \

#/storage/Media/Video/TV/
#/storage/Media/Video/TV/11.22.63
#/storage/Media/Video/TV/1883
#/storage/Media/Video/TV/19-2
#/storage/Media/Video/TV/1923
#/storage/Media/Video/TV/24
#/storage/Media/Video/TV/30.for.30
#/storage/Media/Video/TV/30.for.30.ESPN.Films.Presents
#/storage/Media/Video/TV/30.for.30.Shorts
#/storage/Media/Video/TV/30.for.30.Soccer.Stories
#/storage/Media/Video/TV/7th.Heaven
#/storage/Media/Video/TV/Africa.(2013)
#/storage/Media/Video/TV/American.Crime.Story
#/storage/Media/Video/TV/An.Idiot.Abroad
#/storage/Media/Video/TV/Arrested.Development
#/storage/Media/Video/TV/Band.of.Brothers
#/storage/Media/Video/TV/Baseball
#/storage/Media/Video/TV/BBC.Five.Children.And.It
#/storage/Media/Video/TV/BBC.Narnia
#/storage/Media/Video/TV/Benjamin.Franklin.(2022)
#/storage/Media/Video/TV/Better.Call.Saul
#/storage/Media/Video/TV/Black.Mirror
#/storage/Media/Video/TV/Blackadder
#/storage/Media/Video/TV/Blue.Planet.(2001)
#/storage/Media/Video/TV/Blue.Planet.II
#/storage/Media/Video/TV/Bluey.(2018)
#/storage/Media/Video/TV/Bob's.Burgers
#/storage/Media/Video/TV/Brass.Eye
#/storage/Media/Video/TV/Breaking.Bad
#/storage/Media/Video/TV/Bridgerton
#/storage/Media/Video/TV/Brooklyn.Nine-Nine
#/storage/Media/Video/TV/Chernobyl
#/storage/Media/Video/TV/Civil.War
#/storage/Media/Video/TV/Colin.from.Accounts
#/storage/Media/Video/TV/Country.Music
#/storage/Media/Video/TV/Crashing.(2017)
#/storage/Media/Video/TV/CSI
#/storage/Media/Video/TV/Curb.Your.Enthusiasim
#/storage/Media/Video/TV/Danger.Mouse
#/storage/Media/Video/TV/David.Attenborough
#/storage/Media/Video/TV/David.Attenboroughs.First.Life
#/storage/Media/Video/TV/David.Attenboroughs.Rise.of.Animals.Triumph.of.the.Vertebrates
#/storage/Media/Video/TV/Dawson's.Creek
#/storage/Media/Video/TV/Derry.Girls
#/storage/Media/Video/TV/Downton.Abbey
#/storage/Media/Video/TV/Dragons
#/storage/Media/Video/TV/DuckTales
#/storage/Media/Video/TV/Entourage
#/storage/Media/Video/TV/ER
#/storage/Media/Video/TV/Eureka
#/storage/Media/Video/TV/Extras
#/storage/Media/Video/TV/Fargo
#/storage/Media/Video/TV/Father.Ted
#/storage/Media/Video/TV/Fawlty.Towers
#/storage/Media/Video/TV/Fear.The.Walking.Dead
#/storage/Media/Video/TV/Firefly
#/storage/Media/Video/TV/Five.Came.Back
#/storage/Media/Video/TV/Flight.Of.The.Conchords
#/storage/Media/Video/TV/Frank.Lloyd.Wright
#/storage/Media/Video/TV/Freaks.and.Geeks
#/storage/Media/Video/TV/Friday.Night.Lights
#/storage/Media/Video/TV/Friends
#/storage/Media/Video/TV/From
#/storage/Media/Video/TV/Frozen.Planet.(2011)
#/storage/Media/Video/TV/Frozen.Planet.II.(2022)
#/storage/Media/Video/TV/Futurama
#/storage/Media/Video/TV/Game.of.Thrones
#/storage/Media/Video/TV/Gavin.And.Stacey
#/storage/Media/Video/TV/Generation.Kill
#/storage/Media/Video/TV/Gilmore.Girls
#/storage/Media/Video/TV/Good.Omens
#/storage/Media/Video/TV/Gorillas.Revisited.with.Sir.David.Attenborough
#/storage/Media/Video/TV/Greys.Anatomy
#/storage/Media/Video/TV/Hemingway
#/storage/Media/Video/TV/Homeland
#/storage/Media/Video/TV/House.of.Cards.(US)
#/storage/Media/Video/TV/House.of.David
#/storage/Media/Video/TV/House.of.the.Dragon
#/storage/Media/Video/TV/Im.Alan.Partridge
#/storage/Media/Video/TV/Inspector.Gadget.(2015)
#/storage/Media/Video/TV/Invincible.(2021)
#/storage/Media/Video/TV/It's.Always.Sunny.in.Philadelphia
#/storage/Media/Video/TV/Jazz
#/storage/Media/Video/TV/John.Adams
#/storage/Media/Video/TV/Kim's.Convenience
#/storage/Media/Video/TV/Knowing.Me.Knowing.You
#/storage/Media/Video/TV/Lewis.and.Clark-.The.Journey.of.the.Corps.of.Discovery
#/storage/Media/Video/TV/Life.(2009)
#/storage/Media/Video/TV/Life.In.Cold.Blood.(2008)
#/storage/Media/Video/TV/Life.In.The.Freezer.(1993)
#/storage/Media/Video/TV/Life.In.The.Undergrowth.(2005)
#/storage/Media/Video/TV/Life.Of.Birds.(1998)
#/storage/Media/Video/TV/Life.Of.Mammals.(2002)
#/storage/Media/Video/TV/Life.On.Earth.(1979)
#/storage/Media/Video/TV/Long.Way.Up
#/storage/Media/Video/TV/Lost
#/storage/Media/Video/TV/Mad.Men
#/storage/Media/Video/TV/Madagascar.(2011)
#/storage/Media/Video/TV/Making.a.Murderer
#/storage/Media/Video/TV/Marvel's.The.Punisher
#/storage/Media/Video/TV/Masters.of.the.Air
#/storage/Media/Video/TV/Medici.Masters.of.Florence
#/storage/Media/Video/TV/Mid.Morning.Matters.with.Alan.Partridge
#/storage/Media/Video/TV/Modern.Family
#/storage/Media/Video/TV/Monty.Pythons.Flying.Circus
#/storage/Media/Video/TV/Mr.Robot
#/storage/Media/Video/TV/Muhammad.Ali
#/storage/Media/Video/TV/Narcos
#/storage/Media/Video/TV/Narcos.Mexico
#/storage/Media/Video/TV/Nashville.(2012)
#/storage/Media/Video/TV/Natures.Great.Events.(2009)
#/storage/Media/Video/TV/Not.for.Ourselves.Alone-.The.Story.of.Elizabeth.Cady.Stanton.&.Susan.B.Anthony
#/storage/Media/Video/TV/Oliver.Stone's.Untold.History.of.the.United.States
#/storage/Media/Video/TV/Once.Upon.a.Time.in.Northern.Ireland
#/storage/Media/Video/TV/Oppenheimer.(1980)
#/storage/Media/Video/TV/Outnumbered
#/storage/Media/Video/TV/Parks.and.Recreation
#/storage/Media/Video/TV/Phoenix.Nights
#/storage/Media/Video/TV/Planet.Earth.(2006)
#/storage/Media/Video/TV/Planet.Earth.II
#/storage/Media/Video/TV/Planet.Earth.III
#/storage/Media/Video/TV/Pride.and.Prejudice
#/storage/Media/Video/TV/Prison.Break
#/storage/Media/Video/TV/Private.Life.Of.Plants.(1995)
#/storage/Media/Video/TV/Prohibition
#/storage/Media/Video/TV/Queen.Charlotte-.A.Bridgerton.Story
#/storage/Media/Video/TV/Rick.and.Morty
#/storage/Media/Video/TV/Rome
#/storage/Media/Video/TV/Rose.Red
#/storage/Media/Video/TV/Roswell
#/storage/Media/Video/TV/Salems.Lot
#/storage/Media/Video/TV/Schitt's.Creek
#/storage/Media/Video/TV/Seinfeld
#/storage/Media/Video/TV/Severance
#/storage/Media/Video/TV/Sherlock
#/storage/Media/Video/TV/Shōgun.(2024)
#/storage/Media/Video/TV/Silicon.Valley
#/storage/Media/Video/TV/Silo
#/storage/Media/Video/TV/South.Park
#/storage/Media/Video/TV/Sports.Night
#/storage/Media/Video/TV/Star.Trek.Deep.Space.9
#/storage/Media/Video/TV/Star.Trek.Discovery
#/storage/Media/Video/TV/Star.Trek.Enterprise
#/storage/Media/Video/TV/Star.Trek.Lower.Decks
#/storage/Media/Video/TV/Star.Trek.Picard
#/storage/Media/Video/TV/Star.Trek.Prodigy
#/storage/Media/Video/TV/Star.Trek.Strange.New.Worlds
#/storage/Media/Video/TV/Star.Trek.TNG
#/storage/Media/Video/TV/Star.Trek.TOS
#/storage/Media/Video/TV/Star.Trek.Voyager
#/storage/Media/Video/TV/Star.Wars.Ahsoka
#/storage/Media/Video/TV/Star.Wars.Andor
#/storage/Media/Video/TV/Star.Wars.Clone.Wars
#/storage/Media/Video/TV/Star.Wars.Obi.Wan.Kenobi
#/storage/Media/Video/TV/Star.Wars.Rebels
#/storage/Media/Video/TV/Star.Wars.Resistance
#/storage/Media/Video/TV/Star.Wars.The.Acolyte
#/storage/Media/Video/TV/Star.Wars.The.Bad.Batch
#/storage/Media/Video/TV/Star.Wars.The.Book.Of.Boba.Fett
#/storage/Media/Video/TV/Star.Wars.The.Clone.Wars
#/storage/Media/Video/TV/Star.Wars.The.Mandalorian
#/storage/Media/Video/TV/Stephen.King's.N
#/storage/Media/Video/TV/Stephen.Kings.It
#/storage/Media/Video/TV/Stephen.Kings.Nightmares.and.Dreamscapes
#/storage/Media/Video/TV/Stephen.Kings.The.Stand
#/storage/Media/Video/TV/Stranger.Things
#/storage/Media/Video/TV/Succession
#/storage/Media/Video/TV/Suits
#/storage/Media/Video/TV/Tales.of.the.Walking.Dead
#/storage/Media/Video/TV/Ted.Lasso
#/storage/Media/Video/TV/Teen.Titans
#/storage/Media/Video/TV/Teen.Titans.Go!
#/storage/Media/Video/TV/The.Adventures.of.Tintin
#/storage/Media/Video/TV/The.Americans.(2013)
#/storage/Media/Video/TV/The.Bible
#/storage/Media/Video/TV/The.Big.Bang.Theory
#/storage/Media/Video/TV/The.Boys
#/storage/Media/Video/TV/The.Chosen
#/storage/Media/Video/TV/The.Crown
#/storage/Media/Video/TV/The.Day.Today
#/storage/Media/Video/TV/The.End.of.the.F-ing.World
#/storage/Media/Video/TV/The.Expanse
#/storage/Media/Video/TV/The.Fall
#/storage/Media/Video/TV/The.First.World.War
#/storage/Media/Video/TV/The.Great.War
#/storage/Media/Video/TV/The.Handmaid's.Tale
#/storage/Media/Video/TV/The.IT.Crowd
#/storage/Media/Video/TV/The.Jinx.The.Life.and.Deaths.of.Robert.Durst
#/storage/Media/Video/TV/The.Langoliers
#/storage/Media/Video/TV/The.Living.Planet.(1984)
#/storage/Media/Video/TV/The.Lord.of.the.Rings-.The Rings of Power
#/storage/Media/Video/TV/The.Man.in.the.High.Castle
#/storage/Media/Video/TV/The.Mighty.Boosh
#/storage/Media/Video/TV/The.Miracle.Of.Bali.(1969)
#/storage/Media/Video/TV/The.National.Parks-.America's.Best.Idea
#/storage/Media/Video/TV/The.Nativity
#/storage/Media/Video/TV/The.Newsroom.(2012)
#/storage/Media/Video/TV/The.Night.Manager
#/storage/Media/Video/TV/The.Office.UK
#/storage/Media/Video/TV/The.Office.US
#/storage/Media/Video/TV/The.Office.US.Extended.Edition
#/storage/Media/Video/TV/The.Pacific
#/storage/Media/Video/TV/The.Paradise
#/storage/Media/Video/TV/The.People.Of.Paradise.(1960)
#/storage/Media/Video/TV/The.Roosevelts-.An.Intimate.History
#/storage/Media/Video/TV/The.Sandman
#/storage/Media/Video/TV/The.Simpsons
#/storage/Media/Video/TV/The.Sopranos
#/storage/Media/Video/TV/The.Spy
#/storage/Media/Video/TV/The.Stand.(2020)
#/storage/Media/Video/TV/The.Stranger.(2020)
#/storage/Media/Video/TV/The.Thick.Of.It
#/storage/Media/Video/TV/The.Tommyknockers
#/storage/Media/Video/TV/The.Trials.Of.Life.(1990)
#/storage/Media/Video/TV/The.U.S.and.the.Holocaust
#/storage/Media/Video/TV/The.Vietnam.War.(2017)
#/storage/Media/Video/TV/The.Walking.Dead
#/storage/Media/Video/TV/The.Walking.Dead-.Daryl.Dixon
#/storage/Media/Video/TV/The.Walking.Dead-.Dead.City
#/storage/Media/Video/TV/The.Walking.Dead-.The.Ones.Who.Live
#/storage/Media/Video/TV/The.Walking.Dead-.World.Beyond
#/storage/Media/Video/TV/The.War
#/storage/Media/Video/TV/The.West
#/storage/Media/Video/TV/The.West.Wing
#/storage/Media/Video/TV/The.Wingfeather.Saga
#/storage/Media/Video/TV/The.Wire
#/storage/Media/Video/TV/The.World.At.War
#/storage/Media/Video/TV/The.X.Files
#/storage/Media/Video/TV/The.Young.Pope
#/storage/Media/Video/TV/This.Time.with.Alan.Partridge
#/storage/Media/Video/TV/Thomas.Jefferson
#/storage/Media/Video/TV/True.Detective
#/storage/Media/Video/TV/Trust
#/storage/Media/Video/TV/Twenty.Twelve
#/storage/Media/Video/TV/Ulysses.31
#/storage/Media/Video/TV/Under.The.Dome
#/storage/Media/Video/TV/Valley.of.the.Boom
#/storage/Media/Video/TV/Veep
#/storage/Media/Video/TV/Veggietales
#/storage/Media/Video/TV/Vikings
#/storage/Media/Video/TV/Vikings-.Valhalla
#/storage/Media/Video/TV/W1A
#/storage/Media/Video/TV/Wallace.and.Gromit
#/storage/Media/Video/TV/Wallace.and.Gromits.Cracking.Contraptions
#/storage/Media/Video/TV/Wallace.and.Gromits.World.of.Invention
#/storage/Media/Video/TV/We.Own.This.City
#/storage/Media/Video/TV/Westworld
#/storage/Media/Video/TV/Yellowjackets
#/storage/Media/Video/TV/Yellowstone.(2018)
#/storage/Media/Video/TV/Yes.Minister
#/storage/Media/Video/TV/Yes.Prime.Minister
#/storage/Media/Video/TV/Zambezi.(1965)
#/storage/Media/Video/TV/Zoo.Quest.(1954)
#
#
#
#
#/storage/Media/Video/TV/_NOBACKUP/3.Body.Problem
#/storage/Media/Video/TV/_NOBACKUP/Adolescence
#/storage/Media/Video/TV/_NOBACKUP/Adventure.Time
#/storage/Media/Video/TV/_NOBACKUP/Alone
#/storage/Media/Video/TV/_NOBACKUP/Altered.Carbon
#/storage/Media/Video/TV/_NOBACKUP/American.Gods
#/storage/Media/Video/TV/_NOBACKUP/Below.Deck
#/storage/Media/Video/TV/_NOBACKUP/Below.Deck.Down.Under
#/storage/Media/Video/TV/_NOBACKUP/Below.Deck.Mediterranean
#/storage/Media/Video/TV/_NOBACKUP/Below.Deck.Sailing.Yacht
#/storage/Media/Video/TV/_NOBACKUP/Big.Little.Lies
#/storage/Media/Video/TV/_NOBACKUP/Bloodlands.2021
#/storage/Media/Video/TV/_NOBACKUP/Bloodline
#/storage/Media/Video/TV/_NOBACKUP/Boardwalk.Empire
#/storage/Media/Video/TV/_NOBACKUP/Castle.Rock
#/storage/Media/Video/TV/_NOBACKUP/Clarksons.Farm
#/storage/Media/Video/TV/_NOBACKUP/COBRA.(2020)
#/storage/Media/Video/TV/_NOBACKUP/Continuum
#/storage/Media/Video/TV/_NOBACKUP/Dark.Matter.2024
#/storage/Media/Video/TV/_NOBACKUP/Dune.Prophecy
#/storage/Media/Video/TV/_NOBACKUP/Euphoria.(US)
#/storage/Media/Video/TV/_NOBACKUP/Fallout
#/storage/Media/Video/TV/_NOBACKUP/For.All.Mankind
#/storage/Media/Video/TV/_NOBACKUP/Forbrydelsen
#/storage/Media/Video/TV/_NOBACKUP/Formula.1-.Drive.to.Survive
#/storage/Media/Video/TV/_NOBACKUP/Fortitude
#/storage/Media/Video/TV/_NOBACKUP/Foundation.(2021)
#/storage/Media/Video/TV/_NOBACKUP/Gaslit
#/storage/Media/Video/TV/_NOBACKUP/Get.Shorty
#/storage/Media/Video/TV/_NOBACKUP/Halt.and.Catch.Fire
#/storage/Media/Video/TV/_NOBACKUP/High.Stakes.Poker
#/storage/Media/Video/TV/_NOBACKUP/House.MD
#/storage/Media/Video/TV/_NOBACKUP/Kin
#/storage/Media/Video/TV/_NOBACKUP/Leah.Remini.Scientology.and.the.Aftermath
#/storage/Media/Video/TV/_NOBACKUP/Letterkenny
#/storage/Media/Video/TV/_NOBACKUP/Lost.in.Space.(2018)
#/storage/Media/Video/TV/_NOBACKUP/Mare.of.Easttown
#/storage/Media/Video/TV/_NOBACKUP/Marvel's.Daredevil
#/storage/Media/Video/TV/_NOBACKUP/Marvel's.Jessica.Jones
#/storage/Media/Video/TV/_NOBACKUP/Mayor.of.Kingstown
#/storage/Media/Video/TV/_NOBACKUP/Murdaugh.Murders-.A.Southern.Scandal
#/storage/Media/Video/TV/_NOBACKUP/Nightsleeper
#/storage/Media/Video/TV/_NOBACKUP/Peaky.Blinders
#/storage/Media/Video/TV/_NOBACKUP/Peep.Show
#/storage/Media/Video/TV/_NOBACKUP/Quantum.Leap.(2022)
#/storage/Media/Video/TV/_NOBACKUP/Reacher
#/storage/Media/Video/TV/_NOBACKUP/Rectify
#/storage/Media/Video/TV/_NOBACKUP/Say.Nothing
#/storage/Media/Video/TV/_NOBACKUP/Snowpiercer
#/storage/Media/Video/TV/_NOBACKUP/Squid.Game
#/storage/Media/Video/TV/_NOBACKUP/Station.Eleven
#/storage/Media/Video/TV/_NOBACKUP/Territory.(2024)
#/storage/Media/Video/TV/_NOBACKUP/The.Bear
#/storage/Media/Video/TV/_NOBACKUP/The.Boys.Presents.Diabolical
#/storage/Media/Video/TV/_NOBACKUP/The.Bridge.(2011)
#/storage/Media/Video/TV/_NOBACKUP/The.Bridge.(2013)
#/storage/Media/Video/TV/_NOBACKUP/The.Chosen
#/storage/Media/Video/TV/_NOBACKUP/The.Day.of.the.Jackal
#/storage/Media/Video/TV/_NOBACKUP/The.Good.Wife
#/storage/Media/Video/TV/_NOBACKUP/The.Last.of.Us
#/storage/Media/Video/TV/_NOBACKUP/The.Mist
#/storage/Media/Video/TV/_NOBACKUP/The.Penguin
#/storage/Media/Video/TV/_NOBACKUP/The.Terror
#/storage/Media/Video/TV/_NOBACKUP/The.Tunnel
#/storage/Media/Video/TV/_NOBACKUP/The.Vow
#/storage/Media/Video/TV/_NOBACKUP/The.White.Lotus
#/storage/Media/Video/TV/_NOBACKUP/The.Young.Pope
#/storage/Media/Video/TV/_NOBACKUP/Tour.de.France-.Unchained
#/storage/Media/Video/TV/_NOBACKUP/TURN.Washingtons.Spies
#/storage/Media/Video/TV/_NOBACKUP/Utopia
#/storage/Media/Video/TV/_NOBACKUP/White.House.Plumbers
#/storage/Media/Video/TV/_NOBACKUP/World.Series.of.Poker
#/storage/Media/Video/TV/_NOBACKUP/World.Series.of.Poker.Europe