#!/bin/bash

if [[ $# -ne 1 ]]; then
	echo "build build-single install run remove shell debug unlock script"
	exit 1
fi

version_number=0.0.26

case $1 in
	build)
		flatpak-builder build --install-deps-from=flathub --force-clean --repo=repo --default-branch=$version_number flatpak/org.sokolas.Strimble.yml
		;;
	build-single)
		flatpak build-bundle repo strimble.flatpak org.sokolas.Strimble $version_number
		;;
	install)
		flatpak-builder build --force-clean --repo=repo --install --user flatpak/org.sokolas.Strimble.yml
		;;
	run)
		flatpak run org.sokolas.Strimble
		;;
	remove)
		flatpak uninstall org.sokolas.Strimble
		;;
	shell)
		flatpak-builder --run build flatpak/org.sokolas.Strimble.yml sh
		;;
	debug)
		flatpak-builder --run build flatpak/org.sokolas.Strimble.yml strimble
		;;
	unlock)
		rm ~/.var/app/org.sokolas.Strimble/data/lockfile.lfs
		;;
	sync)
		rsync -a --delete src/ build/files/share/strimble/src/
		rsync -a --delete images/ build/files/share/strimble/images/
		rsync -a --delete lualibs/ build/files/share/strimble/lualibs/
		rsync -a --delete scripts/ build/files/share/strimble/scripts/
		;;
	*)
		exit 1
esac
