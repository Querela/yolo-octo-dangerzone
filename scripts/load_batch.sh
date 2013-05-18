#!/bin/bash

#
# load_batch.sh
# Batch file to get all urls in the batch file from IA 2013
#

batchFile=$1

###############################################################################

# Checking input batch file
if [ ${batchFile##*.} != "zip" ]; then
        echo "ERROR: No Zip-File found."
        exit 1
fi

# Create a fresh working directory
workDir="$(dirname $batchFile)/${batchFile%.*}"

echo "Working in \"$workDir\" ..."

if [ -e "$workDir" ]; then
	read -r -p "Remove \"$workDir\". Are you sure? [Y/n]} " response
	#if [ "$response" = "Y" ]; then
	if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
		rm -r "$workDir"
	fi
fi

mkdir -p "$workDir"

###############################################################################

tempFileNr=0

# Iterate over all entries in the batch file
for file in `unzip -qq -l "$batchFile" | awk '{print $4}'`; do
	((tempFileNr += 1))

	echo "----------"
	echo "Working on $file:"

	#targetFile="$workDir/$tempFileNr/tempfile_$tempFileNr"

	# Unzip single entry into $workDir
	unzip -q "$batchFile" "$file" -d "$workDir"

	# Files to work on
	inFile="$workDir/$file"
	outFile="$workDir/${file}.out"
	curlStatusFile="$workDir/$file.curl.status"
	> "$curlStatusFile"

	# Replace ; with tabs for awk tool
	sed -e "s/;/\t/g" "$inFile" > "$outFile" 

	outDir="${inFile%.*}"
	mkdir "$outDir"

	#######################################################################

	while read line
	do
		((lineNr += 1))
		url=`echo "$line" | awk '{print $1}'`
		categ=`echo "$line" | awk '{print $2}'`
		#echo "Processing $url with category $categ."

		urlFile="$outDir/page_$lineNr.htm"
		headerFile="$outDir/header_$lineNr.txt"

		# Get document with cURL
		# Options: --compressed, --create-dirs, --fail ?
		curlStatus=`curl --dump-header "$headerFile" --output "$urlFile" --retry 3 --location --write-out "$tempFileNr-$lineNr: [%{http_code}] - Got \"$url\" -> \"%{url_effective}\" -> \"$urlFile\" (%{size_download} Bytes)\n" -# "$url"`
		echo $curlStatus

		# Get response code
		ok=`cat "$headerFile" | grep -e "HTTP/1.1 200 OK"`
		if [ "$ok" = "" ]; then
			echo "ERROR in $tempFileNr-$lineNr ?"
			> "$urlFile.fail"
			echo "$tempFileNr-$lineNr: ERROR - \"$url\" -> \"$urlFile.fail\"" >> "$curlStatusFile"
			continue
		fi

		echo "$curlStatus" >> "$curlStatusFile"

		# Get keywords
		keywordFile="$outDir/keywords_$lineNr.txt"
		#cat "$urlFile" | grep "keywords" > "$keywordFile"

	done < "$outFile"

	#######################################################################


done
