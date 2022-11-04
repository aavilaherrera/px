PX_TOOLS := px px_completion.bash px_digikam-extract-faces.bash px_refine-known-faces.bash
INSTALL_DIR := ~/.local/bin
CONFIG_DIR := ~/.config/px
DATA_DIR := ~/.local/share/px
EXTRAS_DIR := $(DATA_DIR)/extras

.PHONY: all test install clean

install: $(PX_TOOLS)
	mkdir -p $(INSTALL_DIR) $(CONFIG_DIR) $(EXTRAS_DIR)
	cp px $(INSTALL_DIR)/
	cp px_digikam-extract-faces.bash px_refine-known-faces.bash $(EXTRAS_DIR)/
	cp px_completion.bash $(CONFIG_DIR)/

	@echo "Add the following line to your .bashrc to enable tab completion:"
	@echo "    source $(CONFIG_DIR)/px_completion.bash"

clean:
	- rm -rf ./test

test: clean
	@echo Setting up tests
	mkdir -p test
	cp -r ./test-data ./test/src

	@echo
	@echo Test move \(dry run\)
	./px move -d -c ./test/src ./test/dst

	@echo
	@echo Test move
	- ./px move  -c ./test/src ./test/dst

	@echo
	@echo Test rename from date
	- ./px date2filename ./test/dst

	@echo
	@echo Test bin by date
	- ./px by-year-month ./test/dst

	@echo Stub for face recognition
	./px tag-faces ./test/dst

	tree ./test/dst

	@echo Test auto processing
	- ./px auto -y ./test/src ./test/auto
	tree ./test/auto

	@echo Test digikam-extract-faces
	_PX_EXTRAS_DIR=. ./px digikam-extract-faces -d test/known-faces
