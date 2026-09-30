.PHONY: build run app open install dmg-preview release clean

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

release:
	./scripts/package-release.sh

dmg-preview:
	./scripts/package-preview-dmg.sh

clean:
	rm -rf .build build
