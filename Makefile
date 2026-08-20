.PHONY: build diagnose install uninstall check clean

build:
	./scripts/build-ubuntu.sh

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
