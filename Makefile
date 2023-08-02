OUT_NAME = gitmini.sh

install:
	@./configure.sh install $(OUT_NAME)

uninstall:
	@./configure.sh uninstall $(OUT_NAME)
