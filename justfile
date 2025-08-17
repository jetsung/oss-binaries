# 全局配置

set shell := ["bash", "-cu"]

goos := "linux windows darwin"
goarch := "amd64 arm64 loong64"
# goos := "linux"
# goarch := "amd64"

# https://github.com/joseluisq/macosx-sdks/releases
macos_sdk_version := "15.5"
osxcross_path := "/opt/osxcross"

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

install-deps-rust: install-deps
    @echo "Installing Rust dependencies..."
    @SUDO_EXEC=""; \
    if [ "$UID" -eq 0 ]; then \
        SUDO_EXEC=""; \
    else \
        SUDO_EXEC="sudo"; \
    fi && \
    $SUDO_EXEC apt install -y build-essential pkg-config cpio libssl-dev libxml2-dev llvm-dev lzma-dev patch zlib1g-dev

install-deps-rust-macos: install-deps-rust
    @echo "Installing Rust dependencies for macOS..."
    @SUDO_EXEC=""; \
    if [ "$UID" -eq 0 ]; then \
        SUDO_EXEC=""; \
    else \
        SUDO_EXEC="sudo"; \
    fi && \
    if [ ! -f "{{osxcross_path}}/tarballs/MacOSX{{macos_sdk_version}}.sdk.tar.xz" ]; then \
        $SUDO_EXEC git clone "https://github.com/tpoechtrager/osxcross" "{{osxcross_path}}" && \
        $SUDO_EXEC curl -L "https://github.com/joseluisq/macosx-sdks/releases/download/{{macos_sdk_version}}/MacOSX{{macos_sdk_version}}.sdk.tar.xz" -o "{{osxcross_path}}/tarballs/MacOSX{{macos_sdk_version}}.sdk.tar.xz" && \
        UNATTENDED=1 $SUDO_EXEC "{{osxcross_path}}/build.sh"; \
    fi

[group('rust')]
install-rust-target-linux:
    @echo "Installing Rust target for Linux..."
    @for arch in x86_64 aarch64 loongarch64; do \
        rustup target add $arch-unknown-linux-musl; \
    done

[group('rust')]
install-rust-target-windows:
    @echo "Installing Rust target for Windows..."
    @for arch in x86_64 aarch64; do \
        rustup target add $arch-pc-windows-msvc; \
    done

[group('rust')]
install-rust-target-macos:
    @echo "Installing Rust target for macOS..."
    @for arch in x86_64 aarch64; do \
        rustup target add $arch-apple-darwin; \
    done

[group('rust')]
install-rust-target rsosarch:
    @echo "Installing Rust target..."
    @for osarch in {{rsosarch}}; do \
        rustup target add $osarch; \
    done

[group('rust')]
install-rust-alltarget: install-rust-target-linux install-rust-target-windows install-rust-target-macos

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
build-rs: install-rust-alltarget
    @echo "Building Rust project..."
    @cd repo && \
        rsosarch="x86_64-unknown-linux-musl aarch64-unknown-linux-musl loongarch64-unknown-linux-musl x86_64-pc-windows-msvc aarch64-pc-windows-msvc x86_64-apple-darwin aarch64-apple-darwin" && \
        files=($(find . \
            -type d \( -path "./tests" \) -prune -false -o \
            -type f -name "Cargo.toml")) && \
        if [[ -f "Cargo.toml" ]]; then \
            for osarch in $rsosarch; do \
                echo "Building $osarch..."; \
                cargo build --release --target=$osarch; \
            done; \
        else \
            for file in ${files[@]}; do \
                for osarch in $rsosarch; do \
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

[group('buildx')]
buildx-rs-linux: install-rust-target-linux
    @echo "Building Rust project with zigbuild"
    @just install-deps-rust
    @cargo install cargo-zigbuild
    @cd repo && \
        rsosarch="x86_64-unknown-linux-musl aarch64-unknown-linux-musl loongarch64-unknown-linux-musl" && \
        files=($(find . \
            -type d \( -path "./tests" \) -prune -false -o \
            -type f -name "Cargo.toml")) && \
        if [[ -f "Cargo.toml" ]]; then \
            for osarch in $rsosarch; do \
                echo "Building $osarch..."; \
                cargo zigbuild --release --target=$osarch; \
            done; \
        else \
            for file in ${files[@]}; do \
                for osarch in $rsosarch; do \
                    echo "Building $osarch... $file"; \
                    cargo zigbuild --release --manifest-path=$file --target=$osarch; \
                done ;\
            done; \
        fi && \
        echo && \
        echo "Rust project built successfully"

[group('buildx')]
buildx-rs-windows: install-rust-target-windows
    @echo "Building Rust project with xwin"
    @just install-deps-rust    
    @cargo install cargo-xwin
    @cd repo && \
        rsosarch="x86_64-pc-windows-msvc aarch64-pc-windows-msvc" && \
        files=($(find . \
            -type d \( -path "./tests" \) -prune -false -o \
            -type f -name "Cargo.toml")) && \
        if [[ -f "Cargo.toml" ]]; then \
            for osarch in $rsosarch; do \
                echo "Building $osarch..."; \
                cargo xwin build --release --target=$osarch; \
            done; \
        else \
            for file in ${files[@]}; do \
                for osarch in $rsosarch; do \
                    echo "Building $osarch... $file"; \
                    cargo xwin build --release --manifest-path=$file --target=$osarch; \
                done ;\
            done; \
        fi && \
        echo && \
        echo "Rust project built successfully"

[group('buildx')]
buildx-rs-macos-error: install-rust-target-macos
    @echo "无法构建"
    @echo "Building Rust project with osxcross"
    @just install-deps-rust-macos
    @PATH="{{osxcross_path}}/target/bin:$PATH" \
    AR=x86_64-apple-darwin24.4-ar \
    CC=x86_64-apple-darwin24.4-clang \
    CXX=x86_64-apple-darwin24.4-clang++ \
    RUSTFLAGS="-C linker=x86_64-apple-darwin24.4-clang" \
    CRATE_CC_NO_DEFAULTS=true; \
    cd repo && \
        rsosarch="x86_64-apple-darwin aarch64-apple-darwin" && \
        files=($(find . \
            -type d \( -path "./tests" \) -prune -false -o \
            -type f -name "Cargo.toml")) && \
        if [[ -f "Cargo.toml" ]]; then \
            for osarch in $rsosarch; do \
                echo "Building $osarch..."; \
                cargo build --release --target=$osarch; \
            done; \
        else \
            for file in ${files[@]}; do \
                for osarch in $rsosarch; do \
                    echo "Building $osarch... $file"; \
                    cargo build --release --manifest-path=$file --target=$osarch; \
                done ;\
            done; \
        fi && \
        echo && \
        echo "Rust project built successfully"

[group('buildx')]
buildx-rs-macos:
    # https://hub.docker.com/r/joseluisq/rust-linux-darwin-builder
    @echo "Building Rust project with docker builder"
    @cd repo && \
        rsosarch="x86_64-apple-darwin aarch64-apple-darwin" && \
        files=($(find . \
            -type d \( -path "./tests" \) -prune -false -o \
            -type f -name "Cargo.toml")) && \
        if [[ -f "Cargo.toml" ]]; then \
            for osarch in $rsosarch; do \
                echo "Building $osarch..."; \
                docker run --rm \
                    --volume "${PWD}":/root/src \
                    --workdir /root/src \
                    joseluisq/rust-linux-darwin-builder:1.85.1 \
                    sh -c "cargo build --release --target $osarch"; \
            done; \
        else \
            for file in ${files[@]}; do \
                for osarch in $rsosarch; do \
                    echo "Building $osarch... $file"; \
                    docker run --rm \
                        --volume "${PWD}":/root/src \
                        --workdir /root/src \
                        joseluisq/rust-linux-darwin-builder:1.85.1 \
                        sh -c "cargo build --release --manifest-path=$file --target $osarch"; \
                done; \
            done; \
        fi && \
        echo && \
        echo "Rust project built successfully"
