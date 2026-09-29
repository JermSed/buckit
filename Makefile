.PHONY: build run app open install clean

build:
	swift build

run:
	swift run Buckit

app:
	./scripts/build-app.sh

open: app
	open build/Buckit.app

install: app
	rm -rf /Applications/Buckit.app
	cp -R build/Buckit.app /Applications/
	open /Applications/Buckit.app

clean:
	rm -rf .build build
