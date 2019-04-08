# shortcut for DuckDuckGo lite text search under bash
# opens DDG in w3m; use q or Q to quit, or check the help menu with SHIFT+H
ddg(){
        if ! [ -x "$(command -v w3m)" ]; then
                echo "DDG cli search requires w3m! Installing now..."
                sudo apt install -y w3m w3m-img
        fi

        w3m https://duckduckgo.com/lite?q="$*"
}

