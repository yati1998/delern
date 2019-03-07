#!/usr/bin/env bash

# TODO(dotdoom): fold some commands? Ex.:
#                https://github.com/travis-ci/travis-ci/issues/2285.

set -e

if [ -z "$CI" -a -t 1 ]; then
	echo 'This script is not supposed to be run outside of CI. It may'
	echo 'silently overwrite important files on your filesystem. Press'
	echo 'Ctrl-C to stop now, or ENTER to continue at your own risk.'
	read
	echo 'Proceeding...'
fi

OSX=
if [[ "$OSTYPE" == "darwin"*  ]]; then
	OSX=1
fi

_section() {
	printf "\n\n\e[32m%30s CI: %s\e[m\n\n" \
		"$(TZ=Europe/Zurich date +%Y-%m-%dT%H:%M:%S%z)" \
		"$*" \
		>&2
}

_log_command() {
	printf "\e[34m%s\e[m\n" "$*" >&2
	"$@"
}

# Install all dependencies necessary for the build.
# Prerequisites:
# - nvm
# - bundler
# - pod (OSX)
# Environment:
# - SDK_ROOT
dependencies() {
	_section 'Install and build flutter (may be cached)'
	flutter upgrade >>"${BUILD_LOG?}" || \
		git clone --quiet --depth=2 --branch=beta \
		https://github.com/flutter/flutter.git "${SDK_ROOT?}/flutter"
	flutter precache
	_log_command flutter --version

	_section 'Bundle (for Fastlane)'
	_log_command bundle --version
	bundle install --quiet --clean --deployment

	_section 'NodeJS (Firebase requires Node version > 8)'
	_log_command node --version
	_log_command npm --version

	_section 'Installing Firebase dependencies'
	# This command tries to install fsevents, failing and flooding terminal.
	npm --prefix firebase install >>"${BUILD_LOG?}" 2>&1
	npm --prefix firebase/functions install
	(
		cd firebase/www &&
		../node_modules/.bin/bower --silent --allow-root install
	)

	if [ -n "${OSX?}" ]; then
		_section 'Updating Cocoapods dependencies database'
		_log_command pod --version
		pod setup --silent
	fi
}

# This is a separate function only for Codemagic.
install_debug_keys() {
	# These files are neccessary to build debug version of the app. There
	# are no real secrets inside.
	cp tools/ci/google-services.json \
	   flutter/android/app/google-services.json
	cp tools/ci/org.dasfoo.delern.debug \
	   flutter/ios/Runner/GoogleService-Info/org.dasfoo.delern.debug
	mkdir -p "${HOME?}/.android"
	cp tools/ci/debug.keystore "${HOME?}/.android/debug.keystore"
}

# Build the application in debug mode.
# Prerequisites:
# - dependencies()
# Environment: none.
build() {
	_section 'Generating Flutter files'
	( cd flutter && bundle exec fastlane build ) >>"${BUILD_LOG?}"

	_section 'Running Flutter tests'
	( cd flutter && flutter test --coverage )
	bash <(curl -s https://codecov.io/bash) >>"${BUILD_LOG?}"

	_section 'Building and linting Firebase Realtime DB, Web and Functions'
	npm --prefix firebase run build
	npm --prefix firebase/functions run lint
	npm --prefix firebase/functions run build
	( cd firebase/www && ../node_modules/.bin/polymer lint )

	_section 'Installing debug keys'
	install_debug_keys

	_section 'Building debug version of the app'
	( cd flutter && bundle exec fastlane android build ) >>"${BUILD_LOG?}"
	if [ -n "${OSX?}" ]; then
		( cd flutter && bundle exec fastlane ios build ) \
			>>"${BUILD_LOG?}"
	fi

	_section 'Verifying that the build does not change source files'
	bundle exec fastlane ensure_clean_git >>"${BUILD_LOG?}"
}

deploy() {
	_section 'Installing and configuring gcloud'
	# Since the script is too noisy printing "tar -xv", we drop stderr.
	curl -sSL https://sdk.cloud.google.com | \
		bash -s -- --disable-prompts --install-dir="${SDK_ROOT?}" \
		>/dev/null 2>&1
	# This is needed only for iOS to fetch Fastlane match keys repository.
	git config --global \
		credential.https://source.developers.google.com.helper \
		gcloud.sh
	gcloud version

	echo "${GCLOUD_SERVICE_ACCOUNT_DATA?}" \
		> "${GOOGLE_APPLICATION_CREDENTIALS?}"
	gcloud auth activate-service-account \
	--key-file "${GOOGLE_APPLICATION_CREDENTIALS?}"
	gsutil cp gs://dasfoo-keystore/delern.jks "${ANDROID_KEYSTORE_PATH?}"

	_section 'Verifying that the source tree is clean'
	bundle exec fastlane ensure_clean_git >>"${BUILD_LOG?}"

	_section 'Deploying Firebase'
	PROJECT=delern-debug npm --prefix firebase run deploy
	PROJECT=delern-e1b33 npm --prefix firebase run deploy
	_section 'Publishing Android app'
	( cd flutter && bundle exec fastlane android publish )

	_section 'Verifying that the build does not change source files'
	bundle exec fastlane ensure_clean_git >>"${BUILD_LOG?}"

	if [ -n "${OSX?}" ]; then
		_section 'Publishing iOS app'
		( cd flutter && bundle exec fastlane ios publish )
		# Do not verify clean Git because we know that the build process
		# unfortunately changes the files:
		# https://github.com/flutter/flutter/issues/28802.
	fi
}


cd "$(dirname "$0")/.."
"${1?method name is required}"
