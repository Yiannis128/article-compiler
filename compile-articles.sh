#!/usr/bin/env sh

# Yiannis Charalambous 2021

# Compiles articles from the article directory, turns them into
# html and places them into Source/articles directory.

function show_help() {
    echo "compile-articles.sh script by Yiannis Charalambous 2021
    This script is used to convert markdown files into static html files.
    
    Parameters:
        -d|--article-dir    Set the path of the article directory.
        
        -o|--output-dir     Set the path of the output directory.
        
        -t|--template-path  Set the path to the template html file to use for
                            when creating the articles.
                            
        -h|--help           Display help information."
}

ARTICLES_DIR="articles"
OUTPUT_DIR="Source/articles"
TEMPLATE_FILE="article_template.html"

# Arg processing

ERROR_PARAMS=()
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        -d|--article-dir)
            ARTICLES_DIR=$2
            shift # past argument
            shift # past value
            ;;
        -o|--output-dir)
            OUTPUT_DIR=$2
            shift
            shift
            ;;
        -t|--template-path)
            TEMPLATE_FILE=$2
            shift
            shift
            ;;
        -h|--help)
            show_help
            exit
            ;;
        *)
            ERROR_PARAMS+=("$1")
            shift # past argument
            ;;
    esac
done

if [[ "${#ERROR_PARAMS[@]}" -gt "0" ]];
then
    echo "Error: Unknown parameters: ${ERROR_PARAMS[*]}"
    show_help
fi

compile_article() {
    # Path to the file
    file_path="$1"
    # Name of the file
    file="$(basename $1)"
    # Output file has md replaced with html extension
    output_file="$(echo $file | sed "s/md$/html/g")"
    output_path="$OUTPUT_DIR/$output_file"
    export html_file="$(markdown $file_path)"
    # Get the title of the article to substitute into the template.
    export html_title="$(head -n 1 $file_path | sed 's/# //g')"
    
    # This embedded perl script scans every line for a title and article tag
    # and substitutes it with the html file content. It then pipes it into
    # the output path.
    perl -pe '
        s/{title}/$ENV{html_title}/g;
        s/{article}/$ENV{html_file}/g;
    ' "$TEMPLATE_FILE" > $output_path

    echo "compiled article: $output_path"
}

# Scan every file and folder inside the articles directory.
for file in $ARTICLES_DIR/*; do
    # Check if the file name ends with md. If it does, then
    # it needs to be compiled, else it needs to be just copied.
    if [[ "$file" == *".md" ]];
    then
        echo "compiling: $file"
        compile_article $file
        echo
    else
        # If it is a directory then copy the directory.
        if [ -d "$file" ];
        then
            echo "copying dir: $file"
            echo "to: $OUTPUT_DIR"
            cp -r $file $OUTPUT_DIR
            echo
        fi
    fi
done


