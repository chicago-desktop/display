WIPPY ?= $(abspath ../app/bin/wippy-floppy)
.PHONY: test lint
test:
	cd test && $(WIPPY) test --host wippy.terminal:host
lint:
	python3 ../shell/tools/late-locals.py src
	python3 ../shell/tools/late-locals.py test/src
	cd test && $(WIPPY) lint --ns chicago.display --ns chicago.display.pipes --ns app
