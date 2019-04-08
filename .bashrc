# shortcut for DuckDuckGo lite text search under bash
ddg(){
        if ! [ -x "$(command -v w3m)" ]; then
                echo "DDG cli search requires w3m! Installing now..."
                sudo apt install -y w3m
        fi

        w3m https://duckduckgo.com/lite?q="$*"
}

