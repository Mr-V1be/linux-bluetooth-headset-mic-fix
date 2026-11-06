.PHONY: build build-ubuntu build-mainline diagnose install uninstall check clean

build: build-ubuntu

build-ubuntu:
	./scripts/build-ubuntu.sh

build-mainline:
	./scripts/build-mainline.sh

diagnose:
	./scripts/diagnose.sh

install:
	sudo ./scripts/install.sh

uninstall:
	sudo ./scripts/uninstall.sh

check:
	bash -n scripts/*.sh
	@if command -v shellcheck >/dev/null 2>&1; then shellcheck -x -P scripts scripts/*.sh; else echo "shellcheck not installed; skipped"; fi

clean:
	rm -rf -- build dist
