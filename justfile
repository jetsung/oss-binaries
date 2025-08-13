# 全局配置

set shell := ["bash", "-cu"]

goos := "linux windows darwin"
goarch := "amd64 arm64 loong64"
# goos := "linux"
# goarch := "amd64"

rsosarch := "x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu loongarch64-unknown-linux-gnu x86_64-pc-windows-msvc aarch64-pc-windows-msvc x86_64-apple-darwin aarch64-apple-darwin"

default:
    @echo "Shell is: $SHELL"
    @echo "Bash version: $BASH_VERSION"
    @echo

install-deps:
    @echo "Installing dependencies..."
    @SUDO_EXEC=""; \
    if [ "$UID" -eq 0 ]; then \
        SUDO_EXEC=""; \
    else \
        SUDO_EXEC="sudo"; \
    fi && \
    $SUDO_EXEC apt install -y zip unzip bzip2 tar xz-utils clang cmake

install-deps-rust:
    @echo "Installing Rust dependencies..."
    @SUDO_EXEC=""; \
    if [ "$UID" -eq 0 ]; then \
        SUDO_EXEC=""; \
    else \
        SUDO_EXEC="sudo"; \
    fi && \
    $SUDO_EXEC apt install -y cpio libssl-dev libxml2-dev llvm-dev lzma-dev patch zlib1g-dev

install-rust-target:
    @echo "Installing Rust target..."
    @for osarch in {{rsosarch}}; do \
        rustup target add $osarch; \
    done

[group('build')]
build-go:
    @echo "Building Go project..."
    @cd repo && \
        files=($(find . \
            -type d \( -path "./vendor" -o -path "./tests" \) -prune -false -o \
            -type f -name "*.go" -exec grep -l "^func main() {" {} +)) && \
        _current_file="${files[1]:-}" && \
        _main_file="${files[0]}" && \
        if [ -n "$_current_file" ]; then _main_file="$_current_file"; fi && \
        _main_dir=$(dirname "$_main_file") && \
        if [ -f "$_main_dir/go.mod" ]; then \
            cd "$_main_dir"; \
        fi && \
        _proj_name=$(grep module go.mod | awk -F/ '{print $NF}') && \
        go mod tidy && \
        go mod vendor && \
        go mod verify && \
        echo && \
        rm -rf dist && \
        for os in {{goos}}; do \
            for arch in {{goarch}}; do \
                if [ "$arch" = "loong64" ] && [ "$os" != "linux" ]; then \
                    continue; \
                fi && \
                echo "Building $os $arch..." && \
                _ext="" && \
                if [ "$os" = "windows" ]; then \
                    _ext=".exe"; \
                fi && \
                GOOS=$os GOARCH=$arch go build -o "dist/${_proj_name}-$os-$arch$_ext" "$_main_dir"; \
            done; \
        done; \
        echo && \
        echo "Go project built successfully" && \
        echo && \
        cd dist && \
        echo "Compressing..." && \
        for file in *; do \
            if [[ "$file" == *".exe" ]]; then \
                zipname="${file%.exe}.zip"; \
                echo "zipname: $zipname"; \
                zip -r "$zipname" "$file"; \
            else \
                tar -czvf "$file.tar.gz" "$file"; \
            fi; \
        done && \
        echo "Compression completed"

[group('build')]
build-rs: install-rust-target
    @echo "Building Rust project..."
    @cd repo && \
        files=($(find . \
            -type d \( -path "./tests" \) -prune -false -o \
            -type f -name "Cargo.toml")) && \
        if [[ -f "Cargo.toml" ]]; then \
            for osarch in {{rsosarch}}; do \
                echo "Building $osarch..."; \
                cargo build --release --target=$osarch; \
            done; \
        else \
            for file in ${files[@]}; do \
                for osarch in {{rsosarch}}; do \
                    echo "Building $osarch... $file"; \
                    cargo build --release --manifest-path=$file --target=$osarch; \
                done ;\
            done; \
        fi && \
        echo && \
        echo "Rust project built successfully"

[group('build')]	
build-py:
    @echo "Building Python project"

[group('build')]
build-js:
    @echo "Building JavaScript project"