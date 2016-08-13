#!/bin/bash
#
# @author Rio Astamal <me@rioastamal.net>
# @desc Simple Bash script to manage BCA Bank account
# @version 2016-07-30
# @require curl binary

# Script name used for logger
readonly BCA_SCRIPT_NAME=$(basename $0)

# AWS style versioning
BCA_VERSION="2016-07-30"
BCA_CONFIG_FILE=""

# Flag for debugging
[ -z "$BCA_DEBUG" ] && BCA_DEBUG="false"

# Path to cookie file
[ -z "$BCA_COOKIE_FILE" ] && BCA_COOKIE_FILE="./shbca.cookie"

# Path to temporary directory to store the server response
[ -z "$BCA_OUTPUT_DIR" ] && BCA_OUTPUT_DIR="./tmp"

# Default log file
[ -z "$BCA_LOG_FILE" ] && BCA_LOG_FILE="shbca.log"

# Base URL of the BCA site (no trailing slash)
[ -z "$BCA_BASE_URL" ] && BCA_BASE_URL="https://m.klikbca.com"

# Show response headers
[ -z "$BCA_CURL_SHOW_HEADERS" ] && BCA_CURL_SHOW_HEADERS="yes"

# Timeout
[ -z "$BCA_CURL_TIMEOUT" ] && BCA_CURL_TIMEOUT=120

# Silent the output progress
[ -z "$BCA_CURL_SILENT" ] && BCA_CURL_SILENT="yes"

# Function to show the help message
bca_help()
{
    echo "\
Usage: $0 [OPTIONS]

Where OPTIONS:
  -a ACTION     specify action name using ACTION.
  -c FILE       read config file from FILE
  -i IP         specify IP address using IP. Default value will parse from
                http://wtfismyip.com/text
  -p PASSWD     specify klik BCA password using PASSWD
  -r            dry run mode. Print the curl command.
  -u USER       specify klik BCA username using USER
  -v            print the shgrate version

List of available ACTION:
  - login
  - logout
  - check_balance

shbca is a command line interface to manage BCA Bank account written in Bash.
shbca is free software licensed under MIT. Visit the project homepage
at http://github.com/astasoft/shbca."
}

# Function to display message to inform user to see the help
bca_see_help()
{
    echo "Try '$BCA_SCRIPT_NAME -h' for more information."
}

# Function to get IP address using service from wtfismyip.com
bca_get_ip()
{
    bca_log "Getting ip from http://wtfismyip.com/text"
    local SERVICE_URL='http://wtfismyip.com/text'
    echo $( curl $SERVICE_URLs )
}

# Function to output syslog like output
bca_write_log()
{
    BCA_LOG_MESSAGE="$@"
    BCA_SYSLOG_DATE_STYLE=$( date +"%b %e %H:%M:%S" )
    BCA_HOSTNAME=$( hostname )
    BCA_PID=$$

    # Date Hostname AppName[PID]: MESSAGE
    printf "%s %s %s[%s]: %s\n" \
        "$BCA_SYSLOG_DATE_STYLE" \
        "$BCA_HOSTNAME" \
        "$BCA_SCRIPT_NAME" \
        "$BCA_PID" \
        "${BCA_LOG_MESSAGE}">> "$BCA_LOG_FILE"
}

# Function to log message
bca_log()
{
    [ "$BCA_DEBUG" = "true" ] && echo "[DEBUG]: $@"
    bca_write_log "$@"
}

bca_err() {
    echo "[ERROR]: $@" >&2
    bca_write_log "$@"
}

# Boot process
bca_init()
{
    mkdir -p "$BCA_OUTPUT_DIR"

    # Load config file if has been specified
    [ -f "$BCA_CONFIG_FILE" ] && source "$BCA_CONFIG_FILE"
}

# Function to build request payload to BCA end point
bca_build_request()
{
    # iPhone 6 User Agent
    local UA="Mozilla/5.0 (iPhone; CPU iPhone OS 9_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13B143 Safari/601.1"
    local REQUEST=""
    local METHOD="$1"

    [ -z "$METHOD" ] && METHOD="GET"

    REQUEST="-X $METHOD"
    REQUEST=" $REQUEST --cookie-jar \"$BCA_COOKIE_FILE\""
    REQUEST=" $REQUEST --cookie \"$BCA_COOKIE_FILE\""
    REQUEST=" $REQUEST -H \"User-Agent: $UA\""
    REQUEST=" $REQUEST --connect-timeout $BCA_CURL_TIMEOUT"

    [ "$BCA_CURL_SHOW_HEADERS" = "yes" ] && REQUEST=" $REQUEST -i"
    [ "$BCA_CURL_SILENT" = "yes" ] && REQUEST=" $REQUEST -s"
    [ "$BCA_CURL_NO_CERTIFICATE_CHECK" = "yes" ] && REQUEST=" $REQUEST -k"

    echo $REQUEST
}

# Function to visit bca main page to get the cookie
bca_visit_login()
{
    bca_log "Visiting BCA login URL $BCA_BASE_URL/login.jsp"
    eval "curl $( bca_build_request GET) $BCA_BASE_URL/login.jsp > ${BCA_OUTPUT_DIR}/output_visit_home.html" && {
        bca_log "Saving the output of home visit to ${BCA_OUTPUT_DIR}/curl-get.login.jsp"
        return 0
    }

    bca_err "Failed to fetch BCA login page"
    return 1
}

# Function to check whether log in was successul
bca_is_login_ok()
{
    cat - | grep 'accountstmt.do?value(actions)=menu' && return 0

    return 1
}

# Function to validate variables before login
bca_validate_login()
{
    [ -z "$BCA_LOGIN_USERNAME" ] && {
        bca_err "Missing Klik BCA username"
        exit 1
    }

    [ -z "$BCA_LOGIN_PASSWORD" ] && {
        bca_err "Missing Klik BCA password"
        exit 1
    }

    [ -z "$BCA_LOGIN_IP" ] && {
        bca_err "Missing Klik BCA origin IP address"
        exit 1
    }
}

# Function to login to BCA account and store the cookie
bca_do_login()
{
    bca_validate_login

    # Get the IP address from default service if empty
    [ -z "$BCA_LOGIN_IP" ] && BCA_LOGIN_IP=$( bca_get_ip )

    local LOGIN_LOG="Logging in to $BCA_BASE_URL/authentication.do with data"
    LOGIN_LOG="$LOGIN_LOG username: $BCA_LOGIN_USERNAME, password: $BCA_LOGIN_PASSWORD "
    LOGIN_LOG="$LOGIN_LOG ip address: $BCA_LOGIN_IP"

    local LOGIN_DATA="--data 'value(user_id)=$BCA_LOGIN_USERNAME'"
    LOGIN_DATA="$LOGIN_DATA --data 'value(pswd)=$BCA_LOGIN_PASSWORD'"
    LOGIN_DATA="$LOGIN_DATA --data 'value(Submit)=LOGIN'"
    LOGIN_DATA="$LOGIN_DATA --data 'value(actions)=login'"
    LOGIN_DATA="$LOGIN_DATA --data 'value(user_ip)=$BCA_LOGIN_IP'"
    LOGIN_DATA="$LOGIN_DATA --data 'user_ip=$BCA_LOGIN_IP'"
    LOGIN_DATA="$LOGIN_DATA --data 'value(mobile)=true'"
    LOGIN_DATA="$LOGIN_DATA --data 'mobile=true'"

    local LOGIN_HEADER="-H \"Referer: $BCA_BASE_URL/login.jsp\""
    local OUTFILE=$BCA_OUTPUT_DIR/curl-post.authentication.do.html
    local CMD="curl $( bca_build_request POST ) $LOGIN_DATA $LOGIN_HEADER $BCA_BASE_URL/authentication.do > $OUTFILE"

    bca_log "$LOGIN_LOG"
    bca_log "Executing command -> $CMD"

    [ "$BCA_DRY_DRUN" = "yes" ] && { echo "$CMD"; return 0; }

    eval "$CMD" && {
        bca_log "Saving login output to $OUTFILE"

        cat "$OUTFILE" | bca_is_login_ok >/dev/null && {
            bca_log "successully login to Klik BCA as $BCA_LOGIN_USERNAME"
            return 0
        }
    }

    bca_err "Failed to login to Klik BCA"
    return 1
}

# Function to log out and clear the session
bca_do_logout()
{
    bca_log "Logging out by visiting URL $BCA_BASE_URL/authentication.do?value(actions)=logout"

    local OUTFILE=$BCA_OUTPUT_DIR/curl-get.authentication.do.logout.html
    local CMD="curl -i -s $( bca_build_request ) '$BCA_BASE_URL/authentication.do?value(actions)=logout' > $OUTFILE"
    bca_log "Executing command -> $CMD"

    [ "$BCA_DRY_DRUN" = "yes" ] && { echo "$CMD"; return 0; }

    eval "$CMD" && {
        bca_log "Saving logout output to $OUTFILE"

        cat "$OUTFILE" | grep "Location: $BCA_BASE_URL/login.jsp" && {
            bca_log "successully logout from Klik BCA"
            return 0
        }
    }

    bca_err "Failed to log out from Klik BCA"
    return 1
}

# Function to check BCA account balance
bca_check_balance()
{
    bca_visit_home
}

# Parse the arguments
while getopts a:c:i:p:ru:v BCA_OPT;
do
    case $BCA_OPT in
        a)
            BCA_ACTION="$OPTARG"
        ;;

        c)
            BCA_CONFIG_FILE="$OPTARG"
        ;;

        i)
            BCA_LOGIN_IP="$OPTARG"
        ;;

        p)
            BCA_LOGIN_PASSWORD="$OPTARG"
        ;;

        r)
            BCA_DRY_DRUN="yes"
        ;;

        u)
            BCA_LOGIN_USERNAME="$OPTARG"
        ;;

        v)
            echo "shbca version $BCA_VERSION"
            exit 0
        ;;

        \?)
            bca_help
            exit 1
        ;;
    esac
done

# Run init process
bca_init

case $BCA_ACTION in
    login)
        bca_do_login
    ;;

    logout)
        bca_do_logout
    ;;

    check_balance)
        bca_check_balances
    ;;

    *)
        echo "Unrecognized action."
        bca_see_help
        exit 1
    ;;
esac

exit 0