#!/bin/bash

############
# FILENAME #
############

filename="Stock-Deploy.sh"

# This is  a bash script to deploy and benchmark stock ceph .

#################
# DEBUG OPTRION #
#################

DEBUG=0

####################
# GLOBAL VARIABLES #
####################

host=
system_dist=$(cat /etc/issue)
admin_dir=./Stock_Ceph_Admin
tuning_conf=./mod_vstart_ceph.conf
pool_name=bencher
pg_num=200
pgp_num=200
replica_pg=1
duration_write=10
duration_read=10
obj_size_write=4096
obj_size_read=4096
concurrency_write=32
concurrency_read=32
pool_name_write=$pool_name
pool_name_read=$pool_name
log_dir=./log

#####################
# DEFAULT VARIABLES #
#####################

osd_num=1

##############
# PARAMETERS #
##############

#:<<LEGACY
installation=0
uninstallation=0
startup=0
conf=0
perf=0
#LEGACY

#:<<CURRENT

#CURRENT

#########
# USAGE #
#########

:<<LEGACY
usage="USAGE\n"
usage=$usage"\t$filename [OPTION]\n"
usage=$usage"\t$filename -i {-o [osd_num] | --osd [osd_num]}\n"
usage=$usage"\n"
usage=$usage"OPTIONS:\n"

usage=$usage"\t-i, --install\n"
usage=$usage"\t\tinstall ceph cluster\n"

usage=$usage"\t-e, --erase\n"
usage=$usage"\t\tuninstall ceph cluster\n"

usage=$usage"\t-s, --start\n"
usage=$usage"\t\tstart up ceph service\n"

usage=$usage"\t-c, --conf\n"
usage=$usage"\t\tuse custom configuration to overwrite /etc/ceph/ceph.conf\n"

usage=$usage"\t-p, --perf\n"
usage=$usage"\t\tbenchmark ceph write & read performance\n"

usage=$usage"\t-h, --help\n"
usage=$usage"\t\thelp\n"
LEGACY

#:<<CURRENT

usage="USAGE\n"
usage=$usage"\t$filename [OPTION]\n"
usage=$usage"\t$filename -d {-o [osd_num] | --osd [osd_num]}\n"
usage=$usage"\n"
usage=$usage"OPTIONS:\n"

usage=$usage"\t-d, --deploy\n"
usage=$usage"\t\tdeploy ceph cluster\n"

usage=$usage"\t-p, --purge\n"
usage=$usage"\t\tpurge ceph cluster\n"

usage=$usage"\t-s, --startup\n"
usage=$usage"\t\tstart up ceph service\n"

usage=$usage"\t-c, --conf\n"
usage=$usage"\t\tuse custom configuration to overwrite /etc/ceph/ceph.conf\n"

usage=$usage"\t-b, --bench\n"
usage=$usage"\t\tbenchmark ceph write & read performance\n"

usage=$usage"\t-h, --help\n"
usage=$usage"\t\thelp\n"

#CURRENT

#############
# FUNCTIONS #
#############

# function to print usage
usage_print() {
        printf "$usage"
        exit
}

# function for help
help_me()
{
        cat<<HELP

NAME
        $filename - Wrapper script for ceph-deploy

SYNOPSIS
        A simple script to deploy stock Ceph cluster.

HELP

        # print usage information
        usage_print

        exit 0
}

# change path to admin dir
cd_admin_dir()
{
        cd $admin_dir
}

# create a new admin node dir
new_admin_dir()
{
        # . create a directory to store admin node configuration.
        rm -rf $admin_dir
        mkdir -p $admin_dir
        cd_admin_dir
}

# install ceph-deploy
install_ceph_deploy()
{
        # judge the OS version
        case "$system_dist" in
        *"Ubuntu"*)
                apt-get install ceph-deploy
                ;;
        *"Centos"*)
                yum install ceph-deploy
                ;;
        *) echo "Distribution version can not be recognized";;
        esac
}

# check environment
check_env()
{
        # TODO: check
        install_ceph_deploy
}

# remove previous ceph cluster
remove_ceph()
{
        # remove ceph & ceph-cluster from host
        ceph-deploy purge $host
        ceph-deploy purgedata $host
}

# create a new ceph cluster in admin node
new_ceph()
{
        # remove previous admin dir and create a new one
        new_admin_dir

        # create a new ceph cluster in admin node
        ceph-deploy new $host
}

# install ceph cluster from admin node
install_ceph()
{
        cd_admin_dir

        # install ceph cluster from admin node
        ceph-deploy install $host
}

# create a new monitor daemon
create_mon()
{
        cd_admin_dir

        # create a new monitor daemon
        ceph-deploy mon create $host
}

# gatherkeys
gather_keys()
{
        cd_admin_dir

        # gather keyrings
        ceph-deploy gatherkeys $host
}

# start osd daemon
start_osd()
{
        cd_admin_dir

        i=0
        while [ $i -lt $osd_num  ]; do
                j=$i
                let "i+=1"
                osd_dir=/schooner/data/ceph/osd$j
                rm -rf $osd_dir
                mkdir -p $osd_dir

                ceph-deploy osd prepare $host:$osd_dir
                ceph-deploy osd activate $host:$osd_dir
        done

}

# start all ceph daemons
start_ceph_all()
{
        # judge the OS version
        case "$system_dist" in
        *"Ubuntu"*)
                start ceph-all
                ;;
        *"Centos"*)
                service ceph start
                ;;
        *) echo "Distribution version can not be recognized";;
        esac
}

# stop all ceph daemons
stop_ceph_all()
{
        # judge the OS version
        case "$system_dist" in
        *"Ubuntu"*)
                stop ceph-all
                ;;
        *"Centos"*)
                service ceph stop
                ;;
        *) echo "Distribution version can not be recognized";;
        esac
}

# restart all ceph daemons
restart_ceph_all()
{
        stop_ceph_all
        start_ceph_all
}

# overwrite ceph.conf under /etc/ceph/
overwrite_conf()
{
        cd_admin_dir

        yes | cp $tuning_conf ceph.conf

        # overwrite ceph.conf under /etc/ceph/
        ceph-deploy --overwrite-conf config push $host
}

# create a new pool
new_pool()
{
        cd_admin_dir

        # create a new pool
        ceph osd pool create $pool_name $pg_num $pgp_num
        # the same as set the replicated pg num to zero
        ceph osd pool set $pool_name size $replica_pg
}

# benchmark write perf
bench_write()
{
        echo "SAVE LOG TO:"
        echo $log_dir"/write.log"

        rados bench $duration_write write -b $obj_size_write \
                -t $concurrency_write -p $pool_name_write --no-cleanup \
                2>&1 | tee $log_dir/write.log
}

# benchmark read perf
bench_read()
{
        echo "SAVE LOG TO:"
        echo $log_dir"/read.log"

        rados bench $duration_read seq -b $obj_size_read \
                -t $concurrency_read -p $pool_name_read \
                2>&1 | tee $log_dir/read.log
}

###########
# MODULES #
###########

# DEPLOY_MOD
deploy_mod()
{
        # check ceph-deploy is installed
        check_env

        # remove previous ceph cluster
        remove_ceph

        # create  a new ceph cluster
        new_ceph

        # install ceph
        install_ceph

        # create a new mon
        create_mon

        # gather keys
        gather_keys

        # start osd daemon
        start_osd
}

# PURGE_MOD
purge_mod()
{
        remove_ceph
}

# RE-CONFIG_MOD
reconfig_mod()
{
        # overwrite previous configuration
        overwrite_conf

        # restart ceph daemons
        restart_ceph_all
}

# RESTART_MOD
restart_mod()
{
        # restart all ceph daemons
        restart_ceph_all
}

# BENCHMARK_MOD
benchmark_mod()
{
        # TODO:para list

        # create a new pool
        new_pool

        # benchmark write perf
        bench_write

        # benchmark read perf
        bench_read
}

#########
# DEBUG #
#########

debug()
{
        echo "--------------------"
        echo "|    START_DEBUG    |"
        echo "--------------------"

        help_me

        echo "--------------------"
        echo "|     END_DEBUG    |"
        echo "--------------------"
}

##########
#  MAIN  #
##########
:<<LEGACY

if [ $DEBUG -eq 1 ]; then
        debug
else
        # if parameter number less than 1, print usage
        if [ $# -lt 1 ] ; then
                usage_print
        else
                while [ $# -ge 1 ]; do
                        case $1 in
                        -i | --install )
                                installation=1
                                ;;
                        -e | --erase )
                                uninstallation=1
                                ;;
                        -s | --start )
                                startup=1
                                ;;
                        -c | --conf )
                                conf=1
                                ;;
                        -p | --perf )
                                perf=1
                                ;;
                        -h | --help )
                                help_me
                                ;;
                        * )
                                usage_print
                esac
                shift
                done
        fi
        # end of if [ $# -lt 1 ]


        if [ $installation -eq 1 ] ; then
                deploy_mod
        elif [ $uninstallation -eq 1 ] ; then
                uninstall_mod
        elif [ $startup -eq 1 ] ; then
                restart_mod
        elif [ $conf -eq 1 ] ; then
                reconfig_mod
        elif [ $perf -eq 1 ] ; then
                benchmark_mod
        else
                :
        fi
        # end of if[ $insatll -eq 1 ]

fi
# end of if [ $DEBUG -eq 1 ]
LEGACY

#:<<CURRENT

TEMP=$(getopt -o do:pscbh \
--long deploy,osd:,purge,startup,conf,bench,help \
-n 'Stock-Deploy.sh' -- "$@")

if [ $? != 0 ] ; then echo "Terminating..." >&2;exit 1; fi

eval set -- "$TEMP"

if [ $# -eq 1 ] ; then usage_print ; exit 1; fi

while true ; do
        case "$1" in
                -d | --deploy )
                        case "$2" in
                                -o | --osd )
                                        osd_num=$3
                                        shift 2
                                        ;;
                        esac
                        deploy_mod
                        shift
                        ;;
                -p | --purge )
                        purge_mod
                        shift
                        ;;
                -s | --startup )
                        restart_mod
                        shift
                        ;;
                -c | --conf )
                        reconfig_mod
                        shift
                        ;;
                -b | --bench )
                        benchmark_mod
                        shift
                        ;;
                -h | --help )
                        help_me
                        shift
                        ;;
                -- ) shift; break;;
                * )
                        echo "ERROR" >&2
                        usage_print
                        exit 1
                        ;;
        esac
done

#CURRENT

