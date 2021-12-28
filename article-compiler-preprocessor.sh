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
    val=$(extract_value "author") author=${val:-$author}
    val=$(extract_value "category") category=${val:-$category}
    
    unset IFS

    return 0
}

echo "loaded article-compiler-preprocessor.sh"