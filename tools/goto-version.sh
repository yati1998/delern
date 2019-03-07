#!/usr/bin/env bash

IFS=. read -r MAJOR MINOR PATCH \
	<<< "${1?version number is a required argument}"

COMMIT="${MAJOR?}.${MINOR?}"
if [ -n "${PATCH}" ]; then
	COMMIT="$(
		git rev-list --topo-order "${MAJOR?}.${MINOR?}"..origin/master |
		tail -n "${PATCH?}" | head -1
	)"
fi
exec git checkout "${COMMIT?}"
