#!/usr/bin/env sh

# Yiannis Charalambous 2021

# Compiles articles from the article directory, turns them into
# html and places them into Source/articles directory.

function println() {
    if [ "$VERBOSE" == "1" ]; then
        echo $@
    fi
}

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
VERBOSE="1"

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

ARTICLES_DIR="articles"
OUTPUT_DIR="Source/articles"
TEMPLATE_FILE="article_template.html"
VERBOSE="1"

println "Articles Directory: $ARTICLES_DIR"
println "Output Directory  : $OUTPUT_DIR"
println "Template File     : $TEMPLATE_FILE"
println "Verbosity         : $VERBOSE"
println
println "Starting to compile articles..."
println

# Reads and removes the params ... endparams section of the article.
# Returns 0 if everything went smoothly.
# Returns 1 if there's no param keyword found on the first line.
preprocess_article() {
    local md_content="$1"
    # Check if first line is params, if not then quit.
    # Need to do this because command substitution removes newlines
    # and replaces them with space.
    IFS=$''
    if [ "$(echo $md_content | head -n 1)" != "params" ];
    then
        return 1
    fi
    
    # Find what line the end params occurs
    end_line_index="0"
    local line_count="0"
    # Printf '%s\n' "$var" is necessary because printf '%s' "$var" on a
    # variable that doesn't end with a newline then the while loop will
    # completely miss the last line of the variable.
    while IFS= read -r line
    do
         # Check for end block
        if [ "$line" == "endparams" ];
        then
            end_line_index="$line_count"
            break
        fi

        let "line_count++"
    done < <(printf '%s\n' "$md_content")

    IFS=$''
    local params_content="$(echo $md_content | head -n $line_count)"
    # Remove params keyword. No need to remove endparams since it is already
    # excluded.
    params_content="$(echo $params_content | tail -n +2)"

    function extract_value() {
        local param="$(echo $params_content | grep $1)"
        local search=":"
        local index=$(expr index "$param" "$search")
        echo ${param:index} | xargs
    }

    # Set variables from parameters
    local val=""
    val=$(extract_value "title") title=${val:-$title}
    # val=$(extract_value "template_overwrite") template_overwrite=${val:-$template_overwrite}
    val=$(extract_value "author") author=title=${val:-$author}

    unset IFS

    return 0
}

compile_article() {
    # Path to the file
    local file_path="$1"
    # Name of the file
    local file_name="$(basename $1)"
    # Output file has md replaced with html extension
    local output_file="$(echo $file_name | sed "s/md$/html/g")"
    local output_path="$OUTPUT_DIR/$output_file"

    # Default variable values set here.
    export title=""
    export reading_time="$(expr $(cat $file_path | wc -w) / 200) minutes"

    # Run the preprocessor to extract all meta data.
    preprocess_article "$(cat $file_path)"
    preprocess_result=$?

    # Need to remove the param block if the preprocessor found it.
    html_article="$(cat $file_path | markdown)"
    if [ "$preprocess_result" -eq "0" ]; then
        IFS=$''
        html_article=$(echo $html_article | tail -n +$(($end_line_index+2)))
        unset IFS
    fi
    export html_article

    perl -pe '
        s/{article}/$ENV{html_article}/g;
        s/{time}/$ENV{reading_time}/g;
        
        s/{title}/$ENV{title}/g;
    ' "$TEMPLATE_FILE" > $output_path

    println "compiled article: $output_path"
}

# Scan every file and folder inside the articles directory.
for file in $ARTICLES_DIR/*; do
    # Check if the file name ends with md. If it does, then
    # it needs to be compiled, else it needs to be just copied.
    if [[ "$file" == *".md" ]];
    then
        println "compiling: $file"
        compile_article $file
        println
    else
        # If it is a directory then copy the directory.
        if [ -d "$file" ];
        then
            println "copying dir: $file"
            println "to: $OUTPUT_DIR"
            cp -r $file $OUTPUT_DIR
            println
        fi
    fi
done
