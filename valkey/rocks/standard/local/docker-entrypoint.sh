#!/bin/sh
set -e

if [ "$(pwd)" = "/" ] && [ -d /data ]; then
	cd /data
fi

# first arg is `-f` or `--some-option`
# or first arg is `something.conf`
if [ "${1#-}" != "$1" ] || [ "${1%.conf}" != "$1" ]; then
	set -- valkey-server "$@"
fi

if [ "$1" = 'valkey-server' ]; then
	inject=1
	for arg; do
		case "$arg" in
			*.conf|--protected-mode|--version|-v|--help|-h)
				inject=0
				break
				;;
		esac
	done
	if [ "$inject" -eq 1 ]; then
		server="$1"
		shift
		set -- "$server" --protected-mode no "$@"
	fi
	if [ "$(id -u)" = '0' ]; then
		find . \! -user valkey -exec chown valkey '{}' +
		exec setpriv --reuid=valkey --regid=valkey --clear-groups -- "$0" "$@"
	else
		if [ ! -w . ]; then
			echo >&2 "warning: directory '$(pwd)' is not writable by current user ($(id -u))"
			echo >&2 "  If persistence is enabled, this will cause errors. Check mount permissions or run as root to allow chown"
		fi
	fi
fi

# set an appropriate umask (if one isn't set already)
um="$(umask)"
if [ "$um" = '0022' ]; then
	umask 0077
fi

exec "$@" $VALKEY_EXTRA_FLAGS
