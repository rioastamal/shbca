## Overview
shbca is a simple tool written in Bash to manage account on Klik BCA.
The main aim of this tool is to quickly get information of balance or
transactions history on your BCA account using
command line interface (CLI).

shbca depends heavily on curl to emulate the browser request.
It uses the mobile site version of Klik BCA to parse the account information.
shbca advertise itself as iPhone device while connecting to Klik BCA.

## Requirements

shbca require Bash (tested with Bash 3.2.57 on Mac OS X El Capitan) and other shell utilities:

* awk
* cat
* curl
* grep
* head
* sed
* tail
* wc

Those shell utilities should be available in most Linux distribution and Unix
compatible OS such as Mac OS X - even Windows using cygwin.

## Installation

Clone the project repository via github:

```
$ git clone git@github.com/astasoft/shbca.git
```

Another altertive is download the zip tarball and extract it somewhere in your box.

## Usage and Examples

Running shbca with `-h` option will give you list of option that shbca supports.

```
$ ./shbca.sh -h
Usage: ./shbca.sh [OPTIONS]

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
at http://github.com/astasoft/shbca.
```

There are few action you can perform using shbca. The list of action are described below.

Action | Description | Prerequisite action
-------|-------------|--------------------
login  | Login to Klik BCA account | -
logout | Logout from Klik BCA account | login
check_balance | Check account balance | login
check_balance_wlogin | Check account balance with auto login and logout | -

### Login to Klik BCA

To login to Klik BCA you need to pass action `login` to shbca. See example below.

```
$ ./shbca -a login -u USERNAME -p -i 8.8.8.8
Enter Klik BCA Password:
Logged in to Klik BCA
```

You can see the log file for details what happening or you can turn on
debug mode by specifying value of environment variable `BCA_DEBUG` to `true`.

```
$ BCA_DEBUG=true ./shbca.sh -a login -u USERNAME -p -i 8.8.8.8
Enter Klik BCA Password:
[DEBUG]: Logging in to https://m.klikbca.com/authentication.do with data username: ******, password: ******  ip address: 8.8.8.8
[DEBUG]: Executing command -> curl -X POST --cookie-jar "./shbca.cookie" --cookie "./shbca.cookie" -H "User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 9_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13B143 Safari/601.1" --connect-timeout 120 -i -s --data 'value(user_id)=******' --data 'value(pswd)=*****' --data 'value(Submit)=LOGIN' --data 'value(actions)=login' --data 'value(user_ip)=8.8.8.8' --data 'user_ip=8.8.8.8' --data 'value(mobile)=true' --data 'mobile=true' -H "Referer: https://m.klikbca.com/login.jsp" https://m.klikbca.com/authentication.do > ./tmp/curl-post.authentication.do.html
[DEBUG]: Saving login output to ./tmp/curl-post.authentication.do.html
[DEBUG]: successully login to Klik BCA as ******
Logged in to Klik BCA
```

### Checking Account Balance

To check your BCA account balance you can use `check_balance` action. Remember to do login action first.

```
$ ./shbca.sh -a check_balance
Account number: 1234567890. Balance left: 799,989,310.29
```

### Checking Account Balance with Auto Login and Logout

This action simplify the process of checking account balance by grouping series of actions into only one. So, you don't have to do login and logout manually. To
run the action you can use `check_balance_wlogin`.

```
$ ./shbca.sh -a check_balance_wlogin -u USERNAME -p -i 8.8.8.8
Enter Klik BCA Password:
Logged in to Klik BCA
Account number: 1234567890. Balance left: 799,989,310.29
Logged out from Klik BCA
```

### Checking Transactions History

To check transactions history (statements) you can use `check_transaction_history` action or the alias `cth`. You need to do login action first.

This action will only grab statements from the last 7 days. Example below uses a config file.

```
$ ./shbca.sh -a check_transaction_history -c ./shbca.config
Found 3 transaction(s). Printing the statements...
TGL   DB/CR KETERANGAN
---   ----- ----------
10/08 DB    TARIKAN ATM 09/08
            0000
            500,000.00
---   ----- ----------
15/08 DB    KARTU KREDIT
            TANGGAL :13/08
            0100 BCA CARD
            54131234567890
            RIO ASTAMAL
            0000
            123,345.00
---   ----- ----------
15/08 DB    TARIKAN ATM 14/08
            0000
            500,000.00
---   ----- ----------
```

### Checking Transaction History with Auto Login and Logout

This action simplify checking transactions history by doing the login and logout process automatically. To use it specify `check_transaction_history_wlogin` or `cth_wlogin` for the action. Example below uses a config file.

```
$ ./shbca.sh -a cth_wlogin -c ./sh-bca.config
Logged in to Klik BCA
Found 3 transaction(s). Printing the statements...
TGL   DB/CR KETERANGAN
---   ----- ----------
10/08 DB    TARIKAN ATM 09/08
            0000
            500,000.00
---   ----- ----------
15/08 DB    KARTU KREDIT
            TANGGAL :13/08
            0100 BCA CARD
            54131234567890
            RIO ASTAMAL
            0000
            123,345.00
---   ----- ----------
15/08 DB    TARIKAN ATM 14/08
            0000
            500,000.00
---   ----- ----------
Logged out from Klik BCA
```

### Logout from Klik BCA

By logging out the cookie which track your session will be cleared so you can not perform action which need login as prerequites action.

```
$ ./shbca.sh -a logout
Logged out from Klik BCA
```

## Using Config File

Instead of inputing username, password and other options directly when calling shbca, you can put the option value in configuration file by specifying it using
`-c` option.

As an example below is checking account with auto login using config file named `shbca.config`.

```
$ ./shbca.sh -a check_balance_wlogin -c ./shbca.config
Logged in to Klik BCA
Account number: 1234567890. Balance left: 799,989,310.29
Logged out from Klik BCA
```

At minimum you should only need three values on your config file.

```
#!/bin/bash
#
# shbca config file

# Klik BCA Username
BCA_LOGIN_USERNAME="YOUR_USERNAME"

# Klik BCA Password
BCA_LOGIN_PASSWORD="YOUR_PASSWORD"

# Klik BCA Origin IP
# Leave empty to get default public ip address from wtfismyip.com/text
BCA_LOGIN_IP=8.8.8.8
```

For list of detailed example of other available configuration you can take a look the content of `shbca.config.sample` file.

## Security

Your Klik BCA username and password are very sensitive information.
That's why shbca never log those information in clear text in the log file.
shbca automatically replace it with asterisk characters `******`.

If you are using config file for storing your Klik BCA username and password,
make sure only you that can read the file. Change the permission to very minimal
such as `0600`. Assuming the name of the config file is `shbca.config`.

```
$ chmod 0600 shbca.config
```

## Todo

- Implements money transfer between BCA account

## Author

shbca is written by Rio Astamal <me@rioastamal.net>

## License

shbca is open source licensed under [MIT license](http://opensource.org/licenses/MIT).

## Disclaimer

This tools is created by Rio Astamal it **has no** affiliation
with Bank Central Asia.

### About Klik BCA

Klik BCA https://www.klikbca.com is a service provided by
Bank Central Asia to its customer to do transactions via
internet banking. BCA and Klik BCA are Copyright (c) 2016 by PT Bank Central Asia Tbk.