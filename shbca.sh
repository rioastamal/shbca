#!/bin/bash
#
# @author Rio Astamal <me@rioastamal.net>
# @desc Simple Bash script to manage BCA Bank account
# @require curl binary

# Script name used for logger
readonly BCA_SCRIPT_NAME=$(basename $0)

# AWS style versioning
BCA_VERSION="2020-08-23"
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
  -a ACTION     specify action name using ACTION
  -c FILE       read config file from FILE
  -h            print this help and exit
  -i IP         specify IP address using IP. Default value will parse from
                http://wtfismyip.com/text
  -p            specify klik BCA password. It will prompt an input.
  -r            dry run mode. Print the curl command
  -u USER       specify klik BCA username using USER
  -v            print the shbca version

List of available ACTION:
  - login
  - logout
  - check_balance
  - check_balance_wlogin
  - check_transaction_history
  - check_transaction_history_wlogin
  - cth (alias of check_transaction_history)
  - cth_wlogin (alias of check_transaction_history_wlogin)

shbca is a command line interface to manage BCA Bank account written in Bash.
shbca is free software licensed under MIT. Visit the project homepage
at http://github.com/rioastamal/shbca."
}

# Function to display message to inform user to see the help
bca_see_help()
{
    echo "Try '$BCA_SCRIPT_NAME -h' for more information."
}

# Function to get IP address using service from wtfismyip.com
bca_get_ip()
{
    [ ! -z "$BCA_LOGIN_IP" ] && return 0

    bca_log "Getting ip from http://wtfismyip.com/text"
    local SERVICE_URL='http://wtfismyip.com/text'
    BCA_LOGIN_IP=$( curl -s $SERVICE_URL | sed $'s/\r$//' )
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

# Function to check whether log in was successul
bca_is_login_ok()
{
    cat - | grep 'accountstmt.do?value(actions)=menu' >/dev/null && return 0

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
    bca_get_ip
    bca_validate_login

    # Get the IP address from default service if empty
    [ -z "$BCA_LOGIN_IP" ] && BCA_LOGIN_IP=$( bca_get_ip )

    local LOGIN_LOG="Logging in to $BCA_BASE_URL/authentication.do with data"
    LOGIN_LOG="$LOGIN_LOG username: ******, password: ****** "
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
    local CMD_LOG="$( echo "$CMD" | sed "s/$BCA_LOGIN_PASSWORD/*****/g;s/$BCA_LOGIN_USERNAME/******/g" )"

    bca_log "$LOGIN_LOG"
    bca_log "Executing command -> $CMD_LOG"

    [ "$BCA_DRY_DRUN" = "yes" ] && { echo "$CMD"; return 0; }

    eval "$CMD" && {
        bca_log "Saving login output to $OUTFILE"

        cat "$OUTFILE" | bca_is_login_ok && {
            bca_log "successully login to Klik BCA as *******"
            echo "Logged in to Klik BCA"
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
    local LOGOUT_HEADER="-H \"Referer: $BCA_BASE_URL/authentication.do\""
    local CMD="curl -i -s $( bca_build_request ) $LOGOUT_HEADER '$BCA_BASE_URL/authentication.do?value(actions)=logout' > $OUTFILE"
    bca_log "Executing command -> $CMD"

    [ "$BCA_DRY_DRUN" = "yes" ] && { echo "$CMD"; return 0; }

    eval "$CMD" && {
        bca_log "Saving logout output to $OUTFILE"
        bca_log "successully logout from Klik BCA"
        echo "Logged out from Klik BCA"
        return 0
    }

    bca_err "Failed to log out from Klik BCA"
    return 1
}

# Function to check BCA account balance
bca_check_balance()
{
    bca_log "Checking balance by visiting URL $BCA_BASE_URL/balanceinquiry.do"

    local OUTFILE=$BCA_OUTPUT_DIR/curl-get.balanceinquiry.do.html
    local BALANCE_HEADER="-H \"Referer: $BCA_BASE_URL/authentication.do?value(actions)=menu\""
    local CMD="curl -i -s $( bca_build_request POST ) $BALANCE_HEADER '$BCA_BASE_URL/balanceinquiry.do' > $OUTFILE"
    bca_log "Executing command -> $CMD"

    [ "$BCA_DRY_DRUN" = "yes" ] && { echo "$CMD"; return 0; }

    eval "$CMD" && {
        bca_log "Saving balance output to $OUTFILE"

        # Check for the redirection
        grep "HTTP/1.1 302 Moved Temporarily" "$OUTFILE" > /dev/null && {
            bca_err "Failed to parse balance, you may need to login."
            return 1
        }

        # Row before the marker is the account number
        # Row after the marker is the balance
        local TMP_BALANCE_INFO=$( grep -A 1 -B 1 "color='#0000a7'><b>IDR</td>" "$OUTFILE" )
        bca_log "Result of grep: $TMP_BALANCE_INFO"

        # The last sed is for removing the carriege return \r
        # http://stackoverflow.com/questions/21621722/removing-carriage-return-on-mac-os-x-using-sed

        # The beginning .* is to match the whole line so it is not included in backreference subtitution
        # http://stackoverflow.com/questions/17511639/sed-print-only-matching-group
        local ACCOUNT_NUMBER=$( echo "$TMP_BALANCE_INFO" | head -n 1 | sed "s@.*<td><font size='1' color='#0000a7'><b>\(.*\)</td>@\1@" | sed $'s/\r$//' )
        local BALANCE_LEFT=$( echo "$TMP_BALANCE_INFO" | tail -n 1 | sed "s@.*<td align='right'><font size='1' color='#0000a7'><b>\(.*\)</td>@\1@" | sed $'s/\r$//' )
        echo "Account number: $ACCOUNT_NUMBER. Balance left: $BALANCE_LEFT"

        bca_log "Balance successully parsed -> Account number: $ACCOUNT_NUMBER | Balance: $BALANCE_LEFT"
        return 0
    }

    bca_err "Failed to parse balance from Klik BCA"
    return 1
}

# Function to get a date for X days ago for Unix compatible OS
#
# @param number NUMBER_OF_DAYS - Get the last X days
# @return string YYYY-MM-DD
bca_date_last_xdays_unix()
{
    local NUMBER_OF_DAYS=$1

    date -v -${NUMBER_OF_DAYS}d "+%Y-%m-%d"
}

# Function to get a date for X days ago for Linux compatible OS
#
# @param number NUMBER_OF_DAYS - Get the last X days
# @return string YYYY-MM-DD
bca_date_last_xdays_linux()
{
    local NUMBER_OF_DAYS=$1

    date -d "${NUMBER_OF_DAYS} days ago" "+%Y-%m-%d"
}

# Function to get a date for X days ago for all OS
#
# @param number NUMBER_OF_DAYS - Get the last X days
# @return string YYYY-MM-DD
bca_date_last_xdays()
{
    local NUMBER_OF_DAYS=$1

    case $OSTYPE in
        darwin*)
            bca_date_last_xdays_unix $NUMBER_OF_DAYS
        ;;

        bsd*)
            bca_date_last_xdays_unix $NUMBER_OF_DAYS
        ;;

        solaris*)
            bca_date_last_xdays_unix $NUMBER_OF_DAYS
        ;;

        linux*)
            bca_date_last_xdays_linux $NUMBER_OF_DAYS
        ;;

        cygwin*)
            bca_date_last_xdays_linux $NUMBER_OF_DAYS
        ;;

        *)
            # Our best bet
            bca_date_last_xdays_unix $NUMBER_OF_DAYS
        ;;
    esac
}

# Function to print only parts that contains statement in the HTML
#
# @param string filename
# @return string HTML row contents of statements
bca_parse_html_table_history()
{
    local HTML_CONTENTS=$( cat $1 )
    local BEGIN_LINE=$(( $( echo "$HTML_CONTENTS" | grep -n '<td bgcolor="#e0e0e0" colspan="2"><b>KETERANGAN</td>' | awk -F: '{print $1}' ) + 2 ))
    local END_LINE=$(( $( echo "$HTML_CONTENTS" | grep -n '<td height="21" valign="top"> TAHAPAN<br />5270813205</td>' | awk -F: '{print $1}' ) - 3 ))

    # Take only the lines which contains statement
    echo "$HTML_CONTENTS" | sed -n "${BEGIN_LINE},${END_LINE}p"
}

# Function to parse the statement history to 'table' look alike
#
# @param STDIN - The contents of Klik BCA HTML statement page
# @return string
bca_print_transaction_history()
{
    # sed and awk combo!
    sed "s@.*<tr bgcolor='.*'><td valign='top'>\(.*\)</td><td>\(.*\)<td valign='top'>\(.*\)</td>@\1--\2--\3@" | \
    awk -F'--' 'BEGIN {
        printf("%-5s %-5s %s\n", "TGL", "DB/CR", "KETERANGAN");
        printf("%-5s %-5s %s\n", "---", "-----", "----------");
    } {
        gsub(/[ \t]+$/, "", $1); gsub(/[ \t]+$/, "", $2);
        printf("%-5s %-5s %s\n", $1, $3, $2);
        printf("%-5s %-5s %s\n", "---", "-----", "----------");
    }' | sed $'s/<br>/\\\n            /g'
}

# Function to check the account transaction history (statements)
bca_check_transaction_history()
{
    bca_log "Checking balance by visiting URL $BCA_BASE_URL/accountstmt.do?value(actions)=acctstmtview"

    local OUTFILE=$BCA_OUTPUT_DIR/curl-post.acctstmtview.do.html
    local STATEMENT_HEADER="-H \"Referer: $BCA_BASE_URL/accountstmt.do?value(actions)=acct_stmt\""
    local DATE_NOW=$( bca_date_last_xdays 0 )
    local DATE_7DAYS_AGO=$( bca_date_last_xdays 7 )

    # Replace the shell separator with "-"
    local OLD_IFS=$IFS
    local IFS=-

    # Split the string using IFS
    set $DATE_7DAYS_AGO

    # It should result in 3 variables $1 for year, $2 for month and $3 for date
    local BEGIN_DATE=$3
    local BEGIN_MONTH=$2
    local BEGIN_YEAR=$1

    set $DATE_NOW
    local END_DATE=$3
    local END_MONTH=$2
    local END_YEAR=$1

    IFS=$OLD_IFS

    local STATEMENT_DATA="--data 'value(r1)=1'"
    STATEMENT_DATA="$STATEMENT_DATA --data 'value(D1)=0'"
    STATEMENT_DATA="$STATEMENT_DATA --data 'value(startDt)=$BEGIN_DATE'"
    STATEMENT_DATA="$STATEMENT_DATA --data 'value(startMt)=$BEGIN_MONTH'"
    STATEMENT_DATA="$STATEMENT_DATA --data 'value(startYr)=$BEGIN_YEAR'"
    STATEMENT_DATA="$STATEMENT_DATA --data 'value(endDt)=$END_DATE'"
    STATEMENT_DATA="$STATEMENT_DATA --data 'value(endMt)=$END_MONTH'"
    STATEMENT_DATA="$STATEMENT_DATA --data 'value(endYr)=$END_YEAR'"

    local CMD="curl $( bca_build_request POST ) $STATEMENT_DATA $STATEMENT_HEADER '$BCA_BASE_URL/accountstmt.do?value(actions)=acctstmtview' > $OUTFILE"

    bca_log "Executing command -> $CMD"

    [ "$BCA_DRY_DRUN" = "yes" ] && { echo "$CMD"; return 0; }

    eval "$CMD" && {
        bca_log "Saving statement output to $OUTFILE"

        local STATEMENT_HTML=$( bca_parse_html_table_history $OUTFILE )
        local STATEMENT_NUMBER=$( echo "$STATEMENT_HTML" | wc -l | awk '{print $1}' )

        bca_log "Found $STATEMENT_NUMBER transaction(s)"
        echo "Found $STATEMENT_NUMBER transaction(s). Printing the statements..."
        echo "$STATEMENT_HTML" | bca_print_transaction_history

        return 0
    }

    bca_err "Failed getting transaction history"
    return 1
}

# Parse the arguments
while getopts a:c:hi:pru:v BCA_OPT;
do
    case $BCA_OPT in
        a)
            BCA_ACTION="$OPTARG"
        ;;

        c)
            BCA_CONFIG_FILE="$OPTARG"
        ;;

        h)
            bca_help
            exit 0
        ;;

        i)
            BCA_LOGIN_IP="$OPTARG"
        ;;

        p)
            read -s -p "Enter Klik BCA Password: " BCA_LOGIN_PASSWORD
            echo ""
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
        bca_check_balance
    ;;

    check_balance_wlogin)
        bca_do_login && bca_check_balance
        bca_do_logout
    ;;

    check_transaction_history)
        bca_check_transaction_history
    ;;

    cth)
        bca_check_transaction_history
    ;;

    check_transaction_history_wlogin)
        bca_do_login && bca_check_transaction_history
        bca_do_logout
    ;;

    cth_wlogin)
        bca_do_login && bca_check_transaction_history
        bca_do_logout
    ;;

    *)
        echo "Unrecognized action."
        bca_see_help
        exit 1
    ;;
esac

exit 0