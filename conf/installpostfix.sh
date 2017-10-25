#!/bin/sh

#异常处理
function handleError() {
    if [ "$?" -ne 0 ]; then
        exit 1
    fi
}

#安装环境准备
function preparement(){
    echo "1、Begin to prepare postfix install-requirements"
    if [ ! -d "/root/software" ]; then
        mkdir /root/software
        handleError;
    fi

    wget -c http://42.123.92.19:28080/repo/local.repo -O /etc/yum.repos.d/local.repo
        handleError;
    if [ ! -d "/etc/yum.repos.d/tmp" ]; then
        mkdir /etc/yum.repos.d/tmp
        handleError;
    fi
    cd /etc/yum.repos.d/
    mv *.repo tmp
    mv tmp/local.repo .
    mv tmp/CentOS-Base.repo .
    
    echo "shutdown selinux firewalld,clear iptables"
    setenforce 0
    systemctl stop firewalld
    iptables -P INPUT ACCEPT
    iptables -F
    iptables -X
    iptables -L
    
    echo '2、add MYSQL Repo, Epel Repo >>>>>>>>>>>>>>>>>>>>>>>>>'
    cd /root/software
    yum install -y wget
    wget http://42.123.92.19:28080/repo/mysql-community-release-el7-5.noarch.rpm -O /root/software/mysql-community-release-el7-5.noarch.rpm
    handleError;         
    rpm -ivh mysql-community-release-el7-5.noarch.rpm 
    wget http://42.123.92.19:28080/repo/epel-release-latest-7.noarch.rpm -O  /root/software/epel-release-latest-7.noarch.rpm
    handleError;
    rpm -ivh epel-release-latest-7.noarch.rpm
    echo 'add MYSQL Repo, Epel Repo done <<<<<<<<<<<<<<<<<<<<<<<<'

    echo 'install relative packages>>>>>>>>>>>>>>>>>>>>>>>>>>'
    yum install expect httpd mailx nginx vim gcc gcc-c++ openssl openssl-devel db4-devel ntpdate mysql mysql-devel mysql-server bzip2 php-mysql cyrus-sasl-md5 perl-GD perl-DBD-MySQL perl-GD perl-CPAN perl-CGI perl-CGI-Session perl-rrdtool cyrus-sasl-lib cyrus-sasl-plain cyrus-sasl cyrus-sasl-devel libtool-ltdl-devel telnet mail libicu-devel  -y
    handleError;
    echo 'install relative packages done <<<<<<<<<<<<<<<<<<<<<<<<'
}

#编译安装postfix
function compileInstallpostfix(){
    cd /root/software
    echo 'compile and install postfix>>>>>>>>>>>>>>>>>>>>>>>>>>>'
    yum remove postfix -y
    userdel postfix
    groupdel postdrop
    groupadd -g 2525 postfix
    useradd -g postfix -u 2525 -s /sbin/nologin -M postfix
    groupadd -g 2526 postdrop
    useradd -g postdrop -u 2526 -s /sbin/nologin -M postdrop

    wget http://42.123.92.19:28080/repo/postfix-3.0.1.tar.gz -O postfix-3.0.1.tar.gz
    handleError;
    tar zxvf postfix-3.0.1.tar.gz
    cd postfix-3.0.1
    make makefiles 'CCARGS=-DHAS_MYSQL -I/usr/include/mysql -DUSE_SASL_AUTH -DUSE_CYRUS_SASL -I/usr/include/sasl -DUSE_TLS ' 'AUXLIBS=-L/usr/lib64/mysql -lmysqlclient -lz -lrt -lm -L/usr/lib64/sasl2 -lsasl2   -lssl -lcrypto'
   	make
   	/usr/bin/expect <<-EOF
   	spawn make install
   	expect "install_root:"
	send "\r"
	expect "tempdir:"
	send "/tmp/extmail\r"
	expect "config_directory:"
	send "\r"
	expect "command_directory:"
	send "\r"
	expect "daemon_directory:"
	send "\r"
	expect "data_directory:"
	send "\r"
	expect "html_directory:"
	send "\r"
	expect "mail_owner:"
	send "\r"
	expect "mailq_path:"
	send "\r"
	expect "manpage_directory:"
	send "\r"
	expect "newaliases_path:"
	send "\r"
	expect "queue_directory:"
	send "\r"
	expect "readme_directory:"
	send "\r"
	expect "sendmail_path:"
	send "\r"
	expect "setgid_group:"
	send "\r"
	expect "shlib_directory:"
	send "\r"
	expect "meta_directory:"
	send "\r"
	interact
	expect eof
	EOF
   	# bash /root/expect.sh
    handleError;
    chown -R postfix:postdrop /var/spool/postfix
    chown -R postfix:postdrop /var/lib/postfix/
    chown root /var/spool/postfix
    chown -R root /var/spool/postfix/pid

    postconf -e 'myhostname=mail.ctmcdn.cn'
    postconf -e 'mydomain=ctmcdn.cn'
    postconf -e 'myorigin=$mydomain'  
    postconf -e 'inet_interfaces=all'
    postconf -e 'mydestination=$myhostname, localhost.$mydomain, localhost,$mydomain'
    postconf -e 'mynetworks_style=host'
    postconf -e 'mynetworks=42.123.92.0/24, 10.0.0.0/24, 127.0.0.0/8'
    postconf -e 'relay_domains=$mydestination'
    postconf -e 'alias_maps=hash:/etc/aliases'
    handleError;
    echo 'compile and install postfix done <<<<<<<<<<<<<<<<<<<<<<<<<'

}

##安装dovecot
function installDovecot() {
    echo 'install dovecot>>>>>>>>>>>>>>>>>>>>>>>>'
    cd ~
    yum install -y  dovecot dovecot-mysql
    \cp -rf /root/conf/dovecot/dovecot.conf /etc/dovecot/dovecot.conf
    \cp -rf /root/conf/dovecot/10-auth.conf /etc/dovecot/conf.d/10-auth.conf
    \cp -rf /root/conf/dovecot/10-mail.conf /etc/dovecot/conf.d/10-mail.conf
    \cp -rf /root/conf/dovecot/10-ssl.conf /etc/dovecot/conf.d/10-ssl.conf
    \cp -rf /root/conf/dovecot/10-logging.conf /etc/dovecot/conf.d/10-logging.conf
    \cp -rf /root/conf/dovecot/auth-sql.conf /etc/dovecot/conf.d/auth-sql.conf
    \cp -rf /root/conf/dovecot/dovecot-mysql.conf /etc/dovecot/dovecot-mysql.conf

    if [ ! -d "/var/mailbox" ]; then
        mkdir /var/mailbox
    fi
    chown -R postfix.postfix /var/mailbox/

    echo 'install dovecot done <<<<<<<<<<<<<<<<<<<<<<<<<<<<'
}


function installCourier() {
    echo 'install courier-authlib>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
    cd /root/software
    wget -c http://42.123.92.19:28080/repo/courier-unicode-1.2.tar.bz2 -O courier-unicode-1.2.tar.bz2
    wget -c http://42.123.92.19:28080/repo/courier-authlib-0.66.2.tar.bz2 -O courier-authlib-0.66.2.tar.bz2
    tar xf courier-unicode-1.2.tar.bz2 
    cd courier-unicode-1.2
    ./configure
    make && make install
    cd ../
    tar xf courier-authlib-0.66.2.tar.bz2
    cd courier-authlib-0.66.2
    ./configure \
    --prefix=/usr/local/courier-authlib \
        --sysconfdir=/etc \
        --without-authpam \
        --without-authshadow \
        --without-authvchkpw \
        --without-authpgsql \
        --with-authmysql \
        --with-mysql-libs=/usr/lib64/mysql \
        --with-mysql-includes=/usr/include/mysql \
        --with-redhat \
        --with-authmysqlrc=/etc/authmysqlrc \
        --with-authdaemonrc=/etc/authdaemonrc \
        --with-mailuser=postfix
    make && make install

    chmod 755 /usr/local/courier-authlib/var/spool/authdaemon
    \cp -rf /root/conf/courier-authlib/authdaemonrc  /etc/authdaemonrc
    \cp -rf /root/conf/courier-authlib/authmysqlrc  /etc/authmysqlrc

    cp courier-authlib.sysvinit /etc/init.d/courier-authlib
    chmod +x /etc/init.d/courier-authlib
    chkconfig --add courier-authlib
    chkconfig courier-authlib on
    echo "/usr/local/courier-authlib/lib/courier-authlib" >> /etc/ld.so.conf.d/courier-authlib.conf
    ldconfig -pv 
    service courier-authlib start

    echo 'install courier-authlib done <<<<<<<<<<<<<<<<<<<<<<<<'
} 


##smtp以及虚拟用户相关的设置
function confSmtp() {

    echo 'config smtp postfix >>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
    \cp -rf /root/conf/smtp/smtpd.conf /usr/lib64/sasl2/smtpd.conf
    postconf -e "smtpd_sasl_auth_enable=yes"
    postconf -e "smtpd_sasl_local_domain=''"
    postconf -e "smtpd_recipient_restrictions=permit_mynetworks,permit_sasl_authenticated,reject_unauth_destination"
    postconf -e "broken_sasl_auth_clients=yes"
    postconf -e "smtpd_client_restrictions=permit_sasl_authenticated"
    postconf -e "smtpd_sasl_security_options=noanonymous"
    postconf -e "virtual_mailbox_base=/var/mailbox"
    postconf -e "virtual_mailbox_maps=mysql:/etc/postfix/mysql_virtual_mailbox_maps.cf"
    postconf -e "virtual_mailbox_domains=mysql:/etc/postfix/mysql_virtual_domains_maps.cf"
    postconf -e "virtual_alias_domains="
    postconf -e "virtual_alias_maps=mysql:/etc/postfix/mysql_virtual_alias_maps.cf"
    postconf -e "virtual_uid_maps=static:2525"
    postconf -e "virtual_gid_maps=static:2525"
    postconf -e "virtual_transport=virtual"
    # postconf -e "maildrop_destination_recipient_limit=1"
    # postconf -e "maildrop_destination_concurrency_limit=1"
    # postconf -e "message_size_limit=14336000"
    # postconf -e "virtual_mailbox_limit=20971520"
    # postconf -e "virtual_create_maildirsize=yes"
    # postconf -e "virtual_mailbox_extended=yes"
    # postconf -e "virtual_mailbox_limit_maps=20971520"
    # postconf -e "virtual_mailbox_limit_override=yes"
    # postconf -e "virtual_maildir_limit_message=Sorry, the user's maildir has overdrawn his diskspace quota, please Tidy your mailbox and try again later."
    # postconf -e "virtual_mailbox_limit=yes"

    echo 'config smtp postfix done <<<<<<<<<<<<<<<<<<<<<<<<'
}

##安装Extmail
function installExtmail() {
    cd /root/software
    echo 'install extmail>>>>>>>>>>>>>>>>>>>>>>>>'
    wget http://42.123.92.19:28080/repo/extmail-1.2.tar.gz -O extmail-1.2.tar.gz
    
    if [ ! -d "/var/www/extsuite" ]; then
      mkdir /var/www/extsuite
    fi
    tar xf extmail-1.2.tar.gz -C /var/www/extsuite/
    rm -rf /var/www/extsuite/extmail
    mv /var/www/extsuite/extmail-1.2/ /var/www/extsuite/extmail
    cd /var/www/extsuite/extmail
    \cp -rf /root/conf/extmail/webmail.cf webmail.cf

    mkdir -p /tmp/extmail/upload
    chown -R postfix.postfix /tmp/extmail/
    echo 'install extmail done<<<<<<<<<<<<<<<<<<<<<<<<'
}

function installExtMan() {
    cd /root/software
    echo 'install extman >>>>>>>>>>>>>>>>>>>>>>>>>>>'
    wget http://42.123.92.19:28080/repo/extman-1.1.tar.gz -O extman-1.1.tar.gz

    tar xf extman-1.1.tar.gz -C /var/www/extsuite/
    cd /var/www/extsuite/
    rm -rf extman/
    mv extman-1.1/ extman
    cd extman/
    cp webman.cf.default webman.cf
    chown -R postfix.postfix /var/www/extsuite/extman/cgi/
    chown -R postfix.postfix /var/www/extsuite/extmail/cgi/
    \cp -rf /root/conf/extman/extmail.sql docs/extmail.sql 

    mv /etc/my.cnf /etc/my.cnf.bak
    \cp -rf /root/conf/my.cnf /etc/my.cnf
    service mysql restart
    mysql -uroot < docs/extmail.sql 
    mysql -uroot < docs/init.sql
    rm -rf /etc/my.cnf
    \cp -rf /etc/my.cnf.bak /etc/my.cnf
    mysql -uroot -e "GRANT ALL ON extmail.* to extmail@'%' identified by 'extmail';"
    mysql -uroot -e "FLUSH PRIVILEGES;"

    ######
    cd /var/www/extsuite/extman/docs/
    cp mysql_virtual_* /etc/postfix/
    if [ ! -d "/tmp/extman" ]; then
      mkdir /tmp/extman
    fi
    chown -R postfix.postfix /tmp/extman/

    postfix start
    systemctl enable dovecot saslauthd
    systemctl start dovecot saslauthd
    ss -tnluo | grep :25
    ps aux | grep dovecot
    ps aux | grep saslauthd

    #解决Undefined subroutine &Ext::Utils::sort2name 
    #called at /var/www/extsuite/extmail/libs/Ext/App/Folders.pm line 387问题
    cd /var/www/extsuite/extmail/libs/Ext
	cp Utils.pm /var/www/extsuite/extman/libs/
	cd /var/www/extsuite/extman/libs/Ext
	mv Utils.pm ManUtils.pm
	/var/www/extsuite/extmail/dispatch-init stop
	/var/www/extsuite/extmail/dispatch-init start

    echo 'install extman <<<<<<<<<<<<<<<<<<<<<<<<<<<'
}

#本机测试
function testlocalMail() {
    echo 'Testing ***********'
    /usr/local/courier-authlib/sbin/authtest -s login postmaster@extmail.org extmail

    printf   "postmaster@extmail.org" | openssl base64
    printf   "extmail" | openssl base64

    echo 'Test done*************'
}


function configNgix() {
   cd /root/software
   echo 'Ngix visit'
   \cp -rf /root/conf/extmail/dispatch-init /var/www/extsuite/extmail/dispatch-init
   /var/www/extsuite/extmail/dispatch-init start
   /var/www/extsuite/extman/daemon/cmdserver -v -d 

   \cp -rf /root/conf/ngix/extmail.conf  /etc/nginx/conf.d/extmail.conf
   \cp -rf /root/conf/ngix/fcgi.conf  /etc/nginx/fcgi.conf


   echo 'Install Unix-syslog'
   wget http://42.123.92.19:28080/repo/Unix-Syslog-1.1.tar.gz
   tar xf Unix-Syslog-1.1.tar.gz 
   cd Unix-Syslog-1.1
   perl Makefile.PL
   make && make install
   service nginx start
}


#1、安装环境准备
preparement;

# 2、编译安装postfix
compileInstallpostfix;

#3、安装dovecot
installDovecot;

#4、安装Courier-authlib
installCourier;

#5、smtp以及虚拟用户相关的设置
confSmtp;

#6、安装Extmail
installExtmail;

#7、安装ExtMan
installExtMan;

#8、本机测试
testlocalMail;

#9、配置启动ngix
configNgix;