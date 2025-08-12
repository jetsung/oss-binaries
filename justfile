# 全局配置

set shell := ["bash", "-cu"]

goos := "linux windows darwin"
goarch := "amd64 arm64 loong64"

default:
    @echo "Shell is: $SHELL"
    @echo "Bash version: $BASH_VERSION"
    @echo

list-files:
    ls -la

[group('build')]
build-go:
    @echo "Building Go project..."
    @cd repo && \
        _main_file=$(find . \
            -type d \( -path "./vendor" -o -path "./tests" \) -prune -false -o \
            -type f -name "*.go" -exec grep -l "^func main() {" {} +) && \
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
build-rs:
	@echo "Building Rust project..."

[group('build')]	
build-py:
    @echo "Building Python project"

[group('build')]
build-js:
    @echo "Building JavaScript project"