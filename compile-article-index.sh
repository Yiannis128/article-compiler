#!/usr/bin/env sh

# Yiannis Charalambous 2021-2022

# Scans articles from the article directory, adds them into a list, then
# creates a html page that lists them based on a template.

# Load scripts
source ./article-compiler-preprocessor.sh

function println() {
    if [ "$VERBOSE" == "1" ]; then
        echo $@
    fi
}

function show_help() {
    echo "compile-article-index.sh script by Yiannis Charalambous 2021
    This script is used to create a static HTML articles list from articles in
    a folder.
    
    Parameters:
        -d|--article-dir=$ARTICLES_DIR
            Set the path of the article directory.
        
        -o|--output-path=$OUTPUT_PATH
            Set the path of the output HTML file.
        
        -i|--index-template-path=$INDEX_TEMPLATE_FILE
            Set the path to the index HTML template file to be used to generate
            the main articles page.

        -c|--category-template-path=$CATEGORY_TEMPLATE_FILE
            Set the path to the template HTML file that defines a single 
            category of articles.

        -e|--element-template-path=$ELEMENT_TEMPLATE_FILE
            Set the path to the template html file that defines a single article
            when all the articles are going to be placed in the categories.

        --default-category=$DEFAULT_CATEGORY_NAME
            The name of the default category for articles that do not belong in
            a specific category. 
                            
        -h|--help   Display help information."
}

ARTICLES_DIR="articles"
OUTPUT_PATH="Source/articles.html"
VERBOSE="0"
DEFAULT_CATEGORY_NAME="Other"

INDEX_TEMPLATE_FILE="article-compiler/article_template_index.html"
CATEGORY_TEMPLATE_FILE="article-compiler/article_template_index_category.html"
ELEMENT_TEMPLATE_FILE="article-compiler/article_template_index_element.html"

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
        -o|--output-path)
            OUTPUT_PATH=$2
            shift
            shift
            ;;
        -i|--index-template-path)
            INDEX_TEMPLATE_FILE=$2
            shift
            shift
            ;;
        -c|--category-template-path)
            CATEGORY_TEMPLATE_FILE=$2
            shift
            shift
            ;;
        -e|--element-template-path)
            ELEMENT_TEMPLATE_FILE=$2
            shift
            shift
            ;;
        --default-category)
            DEFAULT_CATEGORY_NAME=$2
            shift
            shift
            ;;
        -q|--quiet)
            VERBOSE="0"
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

# # Sort the array.
# local sorted=
# IFS=$'\n' sorted=($(sort <<<"${articles_list[*]}"))
# Array of file paths to articles.
articles_list=()

# Map <category name, (article path)>
# A map that holds category article array pairs.
declare -A categories
# Map  <article path, title>
# A map that holds article path and title key value pairs.
declare -A titles

function scan_articles() {
    # Scan every file and folder inside the articles directory.
    for file in $ARTICLES_DIR/*; do
        # Check if the file name ends with md. If it does, then
        # it needs to be added to the list, else ignored.
        if [[ "$file" == *".md" ]];
        then
            export category=""
            export title=""
            
            #println "found: $file"
            articles_list+=("$file")
            
            # Scan article for category.
            preprocess_article "$(cat $file)"
            
            # Check if category is not found, if not then set the default one.
            if [ "$category" = "" ]; then
                category="$DEFAULT_CATEGORY_NAME"
            fi

            # Add the article to its respective category.
            # NOTE Maybe aware of first element of array that is a blank
            # empty line.
            categories["$category"]="${categories[$category]}"$'\n'"$file"
            titles["$file"]="$title"

            # Cleanup for next iteration.
            unset category
            unset title
        fi
    done
}

function generate_index() {
    println "generating index..."

    local category_results=""

    # Iterate over every category and add elements.
    for category_name in "${!categories[@]}"; do
        println "handling category: $category_name"
        local article_paths="${categories[$category_name]}"
        local articles_html=""

        # Iterate over every element and generate HTML.
        while IFS= read -r article_path; do
            if [ "$article_path" = "" ]; then continue; fi

            export article_title="${titles["$article_path"]}"
            export article_url="$(echo $article_path | sed "s/md$/html/g")"
            
            local result="$(perl -pe '
                s/{article_title}/$ENV{article_title}/g;
                s/{article_url}/$ENV{article_url}/g;
            ' "$ELEMENT_TEMPLATE_FILE")"
            
            articles_html="$articles_html"$'\n'"$result"
            unset result
        done <<< "$article_paths"

        # Add categories to index.
        export category_name
        export category_articles="$articles_html"
        local category_result="$(perl -pe '
            s/{category_name}/$ENV{category_name}/g;
            s/{category_articles}/$ENV{category_articles}/g;
        ' "$CATEGORY_TEMPLATE_FILE")"

        # Add category result to final html
        category_results="$category_results"$'\n'"$category_result"
        unset category_result
        unset articles_html
    done

    # Create the index file.
    export article_categories="$category_results"
    perl -pe '
        s/{article_categories}/$ENV{article_categories}/g;
    ' "$INDEX_TEMPLATE_FILE" > $OUTPUT_PATH

    println "out: $OUTPUT_PATH"
}

scan_articles

generate_index
