# Faster startup by disabling global compinit (we'll do it manually)

skip_global_compinit=1

# Initialize basic environment first
typeset -U path
export LANG=en_US.UTF-8
export EDITOR='hx'

# Cache commonly used directories
hash -d docs=~/Documents
hash -d dl=~/Downloads

# Optimize command history
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_ALL_DUPS  # Don't record duplicates
setopt HIST_REDUCE_BLANKS    # Remove unnecessary blanks
setopt HIST_VERIFY           # Show history expansion before executing
setopt SHARE_HISTORY         # Share history between sessions
setopt INC_APPEND_HISTORY    # Add commands as they are typed

# Basic PATH setup first
path=(~/.local/bin ~/bin /usr/local/bin ~/.composer/vendor/bin /Applications/CMake.app/Contents/bin $path)
export PATH="/opt/homebrew/opt/mysql@8.0/bin:$PATH"
export PATH


# nvm() {
#     unset -f nvm
#     export NVM_SOURCE=$(brew --prefix nvm)
#     source $NVM_SOURCE/nvm.sh
#     [ -s "$NVM_SOURCE/etc/bash_completion.d/nvm" ] && source "$NVM_SOURCE/etc/bash_completion.d/nvm"
#     nvm "$@"
# }

# Smarter lazy load for Node - only load nvm if command not found
function node_lazy_load() {
    unset -f node npm npx yarn pnpm
    source $(brew --prefix nvm)/nvm.sh
    $0 "$@"
}

for cmd in node npm npx yarn pnpm; do
    eval "${cmd}() { node_lazy_load $cmd \"\$@\" }"
done
# Lazy load pyenv with completion
pyenv() {
    unset -f pyenv
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(command pyenv init -)"
    if [ -d "${PYENV_ROOT}/completions" ]; then
        source "${PYENV_ROOT}/completions/pyenv.zsh"
    fi
    pyenv "$@"
}

# Cache brew prefix for faster startup
export BREW_PREFIX=$(brew --prefix)

# JAVA setup using cached brew prefix
export JAVA_HOME="$BREW_PREFIX/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

# Faster git prompt with caching
function git_prompt_info() {
    ref=$(git symbolic-ref HEAD 2> /dev/null) || return
    echo " %{$fg_bold[green]%}${ref#refs/heads/}%{$reset_color%}"
}

# Enable command correction
setopt CORRECT
setopt CORRECT_ALL

# Better directory navigation
setopt AUTO_CD             # Just type directory name to cd
setopt AUTO_PUSHD          # Push dirs to stack automatically
setopt PUSHD_IGNORE_DUPS   # Don't push duplicates
setopt PUSHD_MINUS         # Make `cd -n` work

# Smarter completions
autoload -Uz compinit
if [ $(date +'%j') != $(/usr/bin/stat -f '%Sm' -t '%j' ~/.zcompdump) ]; then
    compinit
else
    compinit -C
fi

# Better completion options
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' # Case insensitive
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# Enhanced aliases
alias zsh="hx ~/.zshrc"
alias hconf="hx ~/.config/helix/config.toml"
alias hlang="hx ~/.config/helix/languages.toml"
alias ..='cd ..'
alias ...='cd ../..'
alias ll='ls -lGa'
alias g='lazygit'
alias e='hx'
alias md='mkdir -p'
alias rd='rmdir'
alias rm='rm -i'  # Safer remove
alias cp='cp -i'  # Safer copy
alias mv='mv -i'  # Safer move

# Function to create a directory and cd into it
function mcd() {
    mkdir -p "$1" && cd "$1"
}

function snip_and_compress() {
    if [[ $# -ne 3 ]]; then
        echo "Usage: snip_and_compress <filename> <start_time> <end_time>"
        return 1
    fi
    input_file="$1"
    start_time="$2"
    end_time="$3"
    output_file_base="${input_file%.*}"

    if [[ ! -f "$input_file" ]]; then
        echo "Error: Input file '$input_file' does not exist"
        return 1
    fi

    # Compress to MP4
    ffmpeg -i "$input_file" -ss "$start_time" -to "$end_time" \
           -vf "scale=1920:1080" \
           -c:v libx264 -crf 23 -preset medium \
           -c:a aac -b:a 128k \
           "${output_file_base}_compressed.mp4" || return 1

    # Compress to WebM
    ffmpeg -i "$input_file" -ss "$start_time" -to "$end_time" \
           -vf "scale=1920:1080" \
           -c:v libvpx-vp9 -crf 30 -b:v 0 -b:a 128k -c:a libopus \
           "${output_file_base}_compressed.webm" || return 1
}

server() {
    python3 ~/post_server.py
}

# Function to grab the first frame of a video
function grab_frame() {
    if [[ $# -ne 2 ]]; then
        echo "Usage: grab_frame <input_file> <output_image>"
        return 1
    fi

    local input_file="$1"
    local output_image="$2"

    ffmpeg -i "$input_file" -vf "select=eq(n\,0)" -q:v 3 "$output_image"
}

# Function to filter images based on a CSV file
function filter_images() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: filter_images <csv_file>"
        echo "  <csv_file>     : CSV file with filenames to filter."
        return 1
    fi

    local FILENAME_CSV="$1"
    local IMAGE_DIR="./"
    local OUTPUT_DIR="./output"

    if [ ! -r "$FILENAME_CSV" ]; then
        echo "Error: CSV file '$FILENAME_CSV' does not exist or is not readable."
        return 1
    fi

    if [ ! -d "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR"
        echo "Created directory: $OUTPUT_DIR"
    fi

    echo "Contents of IMAGE_DIR ($IMAGE_DIR):"
    ls -l "$IMAGE_DIR"

    echo "Contents of OUTPUT_DIR ($OUTPUT_DIR):"
    ls -l "$OUTPUT_DIR"

    while IFS=, read -r filename; do
        filename=$(echo "$filename" | xargs)

        echo "Processing file: $filename"

        if [[ -f "$IMAGE_DIR$filename" ]]; then
            if [[ ! -f "$OUTPUT_DIR/$filename" ]]; then
                cp "$IMAGE_DIR$filename" "$OUTPUT_DIR/"
                echo "Copied: $filename"
            else
                echo "File already exists in output directory: $filename"
                echo "Updated contents of OUTPUT_DIR ($OUTPUT_DIR):"
                ls -l "$OUTPUT_DIR"
            fi
        else
            echo "File not found: $filename"
        fi
    done < "$FILENAME_CSV"

    echo "Filtering complete."
}


# Initialize zoxide last (it's usually fast)
eval "$(zoxide init --cmd cd zsh)"

# Load Homebrew shell environment last
eval "$(/opt/homebrew/bin/brew shellenv)"

# Better terminal title
precmd() {
    print -Pn "\e]0;%~\a"
}

# Ensure nvm is loaded
export NVM_DIR="$HOME/.nvm"
    [ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ] && \. "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" # This loads nvm
    [ -s "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm" # This loads nvm bash_completion

