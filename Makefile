# dwm - dynamic window manager
# See LICENSE file for copyright and license details.

.SILENT:

include config.mk

USER_HOME ?= $(shell getent passwd $(or $(SUDO_USER),$(USER)) 2>/dev/null | cut -d: -f6)
OWNER     := $(or $(SUDO_USER),$(USER))
DATA_DIR  := ${USER_HOME}/.local/share/dwm-tudor
CFG_DIR   := ${USER_HOME}/.config

SRC = drw.c dwm.c util.c tomlparser.c
OBJ = ${SRC:.c=.o}

all: dwm

.c.o:
	${CC} -c ${CFLAGS} $<

${OBJ}: config.h config.mk

config.h:
	cp config.def.h $@

dwm: ${OBJ}
	${CC} -o $@ ${OBJ} ${LDFLAGS}

clean:
	rm -f dwm ${OBJ} *.orig *.rej

install: all
	@echo ""
	@echo "==> Installing dwm binary and man page..."
	install -Dm755 dwm ${DESTDIR}${PREFIX}/bin/dwm
	sed "s/VERSION/${VERSION}/g" dwm.1 | install -Dm644 /dev/stdin ${DESTDIR}${MANPREFIX}/man1/dwm.1
	install -Dm755 dwm-session ${DESTDIR}${PREFIX}/bin/dwm-session
	@echo "==> Setting up X session entries..."
	if [ ! -d /usr/share/xsessions ]; then \
		mkdir -p /usr/share/xsessions; \
	fi
	install -Dm644 dwm.desktop /usr/share/xsessions/
	if [ -f ${USER_HOME}/.xinitrc ] && ! cmp -s scripts/.xinitrc ${USER_HOME}/.xinitrc \
	   && [ ! -e ${USER_HOME}/.xinitrc.bak-dwm-tudor ]; then \
		cp -a ${USER_HOME}/.xinitrc ${USER_HOME}/.xinitrc.bak-dwm-tudor; \
		echo "    existing ~/.xinitrc saved as ~/.xinitrc.bak-dwm-tudor"; \
	fi
	install -Dm644 scripts/.xinitrc ${USER_HOME}/.xinitrc
	@echo "==> Syncing local repo to data dir..."
	mkdir -p ${DATA_DIR}
	if [ "$$(realpath .)" != "$$(realpath ${DATA_DIR})" ]; then \
		tar --exclude=./.git --exclude=./dwm --exclude='*.o' -cf - . | tar -xf - -C ${DATA_DIR}; \
	fi
	@echo "==> Installing config directories..."
	for dir in config/*/; do \
		b=$$(basename "$$dir"); dst=${CFG_DIR}/$$b; \
		[ -L "$$dst" ] && rm -f "$$dst"; \
		if [ -d "$$dst" ] && [ ! -e "$$dst.bak-dwm-tudor" ]; then \
			cp -a "$$dst" "$$dst.bak-dwm-tudor"; \
		fi; \
		mkdir -p "$$dst"; \
		cp -rfL "$$dir." "$$dst/"; \
	done
	ln -sf ${CFG_DIR}/polybar/themes/minimal/config.ini ${CFG_DIR}/polybar/config.ini
	@echo "==> Installing scripts to PATH..."
	for f in scripts/*; do \
		case "$$(basename $$f)" in autostart*) continue;; esac; \
		install -Dm755 "$$f" ${DESTDIR}${PREFIX}/bin/$$(basename $$f); \
	done
	@echo "==> Seeding user config (skipping existing files)..."
	if [ -d ${CFG_DIR}/dwm-titus ] && [ ! -e ${CFG_DIR}/dwm-tudor ]; then \
		cp -a ${CFG_DIR}/dwm-titus ${CFG_DIR}/dwm-tudor; \
		echo "    migrated ~/.config/dwm-titus -> ~/.config/dwm-tudor (old directory left in place)"; \
	fi
	mkdir -p ${CFG_DIR}/dwm-tudor
	test -f ${CFG_DIR}/dwm-tudor/hotkeys.toml || install -Dm644 config/hotkeys.toml ${CFG_DIR}/dwm-tudor/hotkeys.toml
	test -f ${CFG_DIR}/dwm-tudor/themes.toml  || install -Dm644 config/themes.toml  ${CFG_DIR}/dwm-tudor/themes.toml
	test -f ${CFG_DIR}/dwm-tudor/window-rules.toml || install -Dm644 config/window-rules.toml ${CFG_DIR}/dwm-tudor/window-rules.toml
	@echo "==> Fixing ownership and permissions..."
	find ${DATA_DIR} -name '*.sh' -o -name '*.py' | xargs -r chmod +x
	for dir in config/*/; do \
		b=$$(basename $$dir); \
		find "${CFG_DIR}/$$b" -name '*.sh' -o -name '*.py' 2>/dev/null | xargs -r chmod +x; \
		chown -R ${OWNER}: "${CFG_DIR}/$$b"; \
	done
	chown -R ${OWNER}: ${CFG_DIR}/dwm-tudor
	chown -R ${OWNER}: ${DATA_DIR} && chown ${OWNER}: ${USER_HOME}/.xinitrc 2>/dev/null || true
	@echo ""
	@echo "  dwm installed successfully."
	@echo "  Log out and select 'dwm', or start with: startx"
	@echo ""

uninstall:
	rm -f ${DESTDIR}${PREFIX}/bin/dwm \
		${DESTDIR}${MANPREFIX}/man1/dwm.1 \
		${DESTDIR}${PREFIX}/bin/dwm-session \
		/usr/share/xsessions/dwm.desktop

release: dwm
	mkdir -p release
	cp -f dwm dwm.desktop dwm-session scripts/.xinitrc release/
	cp -rf config scripts release/
	tar -czf release/dwm-tudor-${VERSION}.tar.gz -C release dwm dwm.desktop dwm-session .xinitrc config scripts

.PHONY: all clean install uninstall release
