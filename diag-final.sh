#!/bin/bash
#	USAGE : nice -n -20 ./diag.sh
REPORT_PATH="/tmp/"
usage()
{

    echo -e "*************************************RDK-B DIAGNOSTIC SCRIT********************************"
    echo -e ""
    echo -e "\t-h --help    		= To display help menu"
    echo -e "\t-u --upload             = TFTP IP			(upload or skip) "
    echo -e "\t-p --polling-interval  	= Polling time in seconds 	(300 seconds by default)"
    echo -e "\t-t --total-time  	= Total time in seconds 	(1800 seconds by default)"
    echo -e ""
    echo -e ""
    echo -e "           [NOTE]:To run the script use 'nice -n -20 ./diag-final.sh'"
    echo -e "           [NOTE]:Run this script from the path where the script is located'"
    echo -e ""
    echo -e "*************************************RDK-B DIAGNOSTIC SCRIT********************************"
}
insert_array(){
    eval arg1="$1"
    eval arg2="$2"
    arr=$arg1
    arr=$arr"-$arg2"
    echo $arr
}
value_at_array(){
    count=0
    value=""
    flag=0
    #echo $2
    #echo $1
    for i in `echo $1 | tr '-' '\n'`; do
        if [[ $count == $2 ]]; then
            value=$i
            flag=1
        fi
        count=$(($count+1))
    done
    if [[ $flag == 1 ]]; then
        echo "$value"
    else
        echo "index_out_of_bounds"
    fi
}
update_array(){
    res=""
    count=0
    for i in `echo $1 | tr '-' '\n'`; do
        if [[ $count == $2 ]]; then
            res=$res"$3"
            flag=1
        else
            res=$res"$i"
        fi
        res=$res"-"
        count=$(($count+1))
    done
    val="${res%?}"
    echo $val
}
log_report(){
    eval arg1="$1"
    eval arg2="$2"
    printf "%s %-30s %s\n" "`date`" "$arg1" "$arg2" >> Report
}
upload="NULL"
mode="default_mode"
kb=" KB"
total_time=1800
polling_interval=300 
polling_count=$(($total_time/$polling_interval))
PROCESS_NAME=""
PID_NUM=""
default_flag=0
count=0
while [ "$1" != "" ]; do
    PARAM= $1
    VALUE= $2
    case $PARAM in
        -h | --help)
            usage
            exit
            ;;
        -p | --polling-interval )
            polling_interval=$(($VALUE))
            shift 
            ;;
        -t | --total-time )
            total_time=$(($VALUE))
            shift
            ;;
        -u | --upload)
            upload=$VALUE
            shift
            ;;
	*)
	     mode="special_mode"
	     count=$(($count+1))
	     PROCESS_NAME=`insert_array "$PROCESS_NAME" "$PARAM"`
	     ;;
    esac
    shift
done

if [ -f Report ]
then
  rm Report
fi
#imagename=`cat /version.txt  | grep imagename | cut -d"=" -f2| cut -d":" -f2`
#log_report "IMAGENAME" "\$imagename"
up_time=`uptime | sed 's/.*up \([^,]*\), .*/\1/'`
log_report "UPTIME" "\$up_time"
if [ $mode == "default_mode" ]
then
    mode="default_mode"
    count=19
    PROCESS_NAME="CcspServiceManager-harvester-CcspCrSsp-meshAgent-webpa-CcspCMAgentSsp-CcspPandMSsp-CcspMtaAgentSsp-CcspMoCA-CcspTr069PaSsp-CcspTandDSsp-CcspXdnsSsp-CcspEthAgent-CcspLMLite-PsmSsp-parados-CcspWifiSsp-CcspHomeSecurity-IGD"
fi
i=0
while [[ $i -lt $count ]]; do
    p_name=`value_at_array "$PROCESS_NAME" $i`
    p_num=`pidof $p_name`
    if [ -z $p_num ]
    then
        PID_NUM=`insert_array "$PID_NUM" "NULL"`
        log_report $p_name "NOT_RUNNING"
    else
        PID_NUM=`insert_array "$PID_NUM" "$p_num"`
    fi
    i=$(($i+1))
done
is_still_running(){
    #   0 IF NOT RUNNING FROM THE BEGINING
    #   1 IF CLOSED MID-WAY
    #   2 IF STILL RUNNING
    p_name=$1
    flag=2
    determin=0
    i=0
    while [[ $i -lt $count ]]; do
        temp_proc=`value_at_array "$PROCESS_NAME" $i`
        if [ $temp_proc == $p_name ]
        then
            determin=1
            temp_pid=`value_at_array "$PID_NUM" $i`
            if [[ $temp_pid == "NULL" ]]; then
                flag=0
            else
                curr_pid=`pidof $temp_proc`
                #echo "$temp_proc $temp_pid $curr_pid"
                if [[ $curr_pid != $temp_pid ]]; then
                    flag=1
                fi
            fi
            break
        fi
	i=$(($i+1))
    done
    if [[ $determin == 1 ]]; then
        echo $flag
    else
        echo "PROCESS $1 not present"
    fi
}

getstat() {
    grep 'cpu ' /proc/stat | sed -e 's/  */x/g' -e 's/^cpux//'
}
total_cpu_util(){
    CURSTAT=$(getstat)
    user=`echo $CURSTAT | cut -d 'x' -f 1`
    system=`echo $CURSTAT | cut -d 'x' -f 3`
    idle=`echo $CURSTAT | cut -d 'x' -f 4`
    iowait=`echo $CURSTAT | cut -d 'x' -f 5`
    irq=`echo $CURSTAT | cut -d 'x' -f 6`
    softirq=`echo $CURSTAT | cut -d 'x' -f 7`
    steal=`echo $CURSTAT | cut -d 'x' -f 8`
    util=$( expr $user + $system + $iowait + $irq + $softirq + $steal)
    total_util=$( expr $util + $idle)
    cpu_util=$(( ($util * 100) ))
    cpu_util_percentage=$(($cpu_util/$total_util))
    echo "$cpu_util_percentage"
}
monitor_cpu_util(){
    sum=0
    i=$polling_count
    while [ $i != 0 ]
    do
        curr=$(total_cpu_util)
        sum=$(( $(( $curr ))+ $(( $sum )) ))
        sleep $polling_interval
        i=$(($i-1))
    done
    avg_cpu_util=$(($sum/$polling_count))
    log_report "AVG_CPU_UTIL:" $avg_cpu_util%
    touch Report1
}
monitor_load_avg(){
    load_avg_interval=$((total_time/3))
    load_avg_count=3
    i=$load_avg_count
    while [ $i != 0 ]
    do
    sleep $(($load_avg_interval))
        load_avg=`cat /proc/loadavg`
        log_report "LOAD_AVG:" "\$load_avg"
        i=$(($i-1))
    done
    touch Report2
}
monitor_flash_size(){
    i=$polling_count
    sum_used_ram=0
    sum_free_ram=0
    while [ $i != 0 ]
    do
        used_mem=$((`df -k  /dev | tail -1 | awk '{print $3}'`))
        free_mem=$((`df -k  /dev | tail -1 | awk '{print $4}'`))
        sum_used_ram=$(($sum_used_ram+$used_mem))
        sum_free_ram=$(($sum_free_ram+$free_mem))
        sleep $polling_interval
        i=$(($i-1))
    done
    avg_used_ram=$(($sum_used_ram/$polling_count))
    avg_used_ram="$avg_used_ram$kb"
    avg_free_ram=$(($sum_free_ram/$polling_count))
    avg_free_ram="$avg_free_ram$kb"
    log_report "AVG_FLASH_MEM_USED:" \$avg_used_ram
    log_report "AVG_FLASH_MEM_FREE:" \$avg_free_ram
    touch Report3
}

monitor_proc_memory_util(){
    i=$polling_count
    SUM_PROCESS_MEM=""
    j=0
    #initialize array with zeroes
    k=0
    while [[ $k -lt $count ]]
    do
        SUM_PROCESS_MEM=`insert_array "$SUM_PROCESS_MEM" 0`
        k=$(($k+1))
    done
    while [[ $i != 0 ]]
    do
        j=0
        k=0
        while [[ $k -lt $count ]]; do
            p_name=`value_at_array "$PROCESS_NAME" $k`
#            process_mem=$((`nice -n -20 top -bn1 | grep $p_name | grep -v grep | awk '{print $5}'`))
            process_mem=$((`nice -n -20 ps | grep $p_name | grep -v grep | awk '{print $3}'`))
            if [ -z "$process_mem" ];
            then
                SUM_PROCESS_MEM=`update_array SUM_PROCESS_MEM $k NULL`
                k=$(($k+1))
                continue
            fi
            t_sum_process_mem=$((`value_at_array "$SUM_PROCESS_MEM" $k`))
            t_sum_process_mem=$(($t_sum_process_mem+$process_mem))
            SUM_PROCESS_MEM=`update_array "$SUM_PROCESS_MEM" $k $t_sum_process_mem`
            k=$(($k+1))
        done
        sleep $polling_interval
        i=$(($i-1))
    done
    k=0
    while [[ $k -lt $count ]]; do
        p_name=`value_at_array "$PROCESS_NAME" $k`
        t_sum_proess_mem=$((`value_at_array "$SUM_PROCESS_MEM" $k`))
        if [ $t_sum_proess_mem != "NULL" ];
        then
            t_sum_proess_mem=$((t_sum_proess_mem/$polling_count))
            t_sum_proess_mem="$t_sum_proess_mem$kb"
            log_report "AVG_VSZ_$p_name:" \$t_sum_proess_mem
        fi
        k=$(($k+1))
    done
    touch Report5
}
monitor_dev_memory_util(){
    i=$polling_count
    sum_mem_used=0
    sum_mem_free=0
    SUM_PROCESS_MEM=""
    j=0
    while [[ $i != 0 ]]
    do
        mem_used=`free | grep Mem | awk '{print $3}'`
        mem_free=`free | grep Mem | awk '{print $4}'`
        sum_mem_used=$(($sum_mem_used+$mem_used))
        sum_mem_free=$(($sum_mem_free+$mem_free))
        sleep $polling_interval
        i=$(($i-1))
    done
    avg_mem_used=$(($sum_mem_used/$polling_count))"$kb"
    avg_mem_free=$(($sum_mem_free/$polling_count))"$kb"
    log_report "AVG_DEV_MEM_USED:" \$avg_mem_used
    log_report "AVG_DEV_MEM_FREE:" \$avg_mem_free
    touch Report4
}
monitor_rss_for_pid(){
    i=$polling_count
    SUM_RSS_MEM=""
    j=0
    flag=1
    k=0
    while [[ $k -lt $count ]]; do
        SUM_RSS_MEM=`insert_array "$SUM_RSS_MEM" 0`
        k=$(($k+1))
    done

    while [[ $i != 0 ]]; do
        j=0
        #check if any process dies mid way
        k=0
        while [[ $k -lt $count ]]; do
            p_name=`value_at_array "$PROCESS_NAME" $k`
            check=`is_still_running $p_name`
            if [[ $check == 1 ]]; then
                #break from inner and outer loop
                if [[ $mode == "special_mode" ]]; then
                    flag=0
                fi
                break
            fi
            k=$(($k+1))
        done
        if [ $flag == 0 ]
        then
            break
        fi
        #else sum up the rss for the rest of the processes
        k=0
        while [[ $k -lt $count ]]; do
            p_name=`value_at_array "$PROCESS_NAME" $k`
            pid=""
            if [[ $mode == "default_mode" ]]; then
                pid=`pidof $p_name`
            else
                pid=`value_at_array "$PID_NUM" $k`
            fi
            if [[ -z $pid ]]; then
                SUM_RSS_MEM=`update_array "$SUM_RSS_MEM" $k 0`
                k=$(($k+1))
                continue
            fi
            rss=$((`cat /proc/$pid/smaps | awk '/Rss:/{ sum += $2 } END { print sum }'`))
            temp_rss_sum=`value_at_array "$SUM_RSS_MEM" $k`
            temp_rss_sum=$(($temp_rss_sum+$rss))
            SUM_RSS_MEM=`update_array "$SUM_RSS_MEM" $k $temp_rss_sum`
            k=$(($k+1))
        done
        sleep $polling_interval
        i=$(($i-1))
    done
    k=0
    if [[ $flag == 1 ]]; then
        while [ $k -lt $count ]
        do
            sum_rss=`value_at_array "$SUM_RSS_MEM" $k`
            sum_rss=$(expr "$sum_rss" / "$polling_count")
            pid=`value_at_array "$PID_NUM" $k`
            if [ -z $pid ]
            then
                k=$(($k+1))
                continue
            fi
            sum_rss="$sum_rss$kb"
            proc_name=`value_at_array "$PROCESS_NAME" $k`
            log_report "AVG_RSS_$proc_name:" \$sum_rss
            k=$(($k+1))
        done
    fi
    touch Report6
}
monitor_stack_for_pid(){
    i=$polling_count
    SUM_RSS_MEM=""
    j=0
    flag=1
    k=0
    while [[ $k -lt $count ]]; do
        SUM_RSS_MEM=`insert_array "$SUM_RSS_MEM" 0`
        k=$(($k+1))
    done
    while [[ $i != 0 ]]; do
        j=0
        #check if any process dies mid way
        k=0
        while [[ $k -lt $count ]]; do
            p_name=`value_at_array "$PROCESS_NAME" $k`
            check=`is_still_running $p_name`
            if [[ $check == 1 ]]; then
                #break from inner and outer loop
                if [[ $mode == "special_mode" ]]; then
                    flag=0
                fi
                break
            fi
            k=$(($k+1))
        done
        if [ $flag == 0 ]
        then
            break
        fi
        #else sum up the rss for the rest of the processes
        k=0
        while [[ $k -lt $count ]]; do
            p_name=`value_at_array "$PROCESS_NAME" $k`
            pid=""
            if [[ $mode == "default_mode" ]]; then
                pid=`pidof $p_name`
            else
                pid=`value_at_array "$PID_NUM" $k`
            fi
            if [[ -z $pid ]]; then
                SUM_RSS_MEM=`update_array "$SUM_RSS_MEM" $k 0`
                k=$(($k+1))
                continue
            fi
            rss=$((`grep -A 1 stack /proc/$pid/smaps | awk '/Size:/{ sum += $2 } END { print sum }'`))
            temp_rss_sum=`value_at_array "$SUM_RSS_MEM" $k`
            temp_rss_sum=$(($temp_rss_sum+$rss))
            SUM_RSS_MEM=`update_array "$SUM_RSS_MEM" $k $temp_rss_sum`
            k=$(($k+1))
        done
        sleep $polling_interval
        i=$(($i-1))
    done
    k=0
    if [[ $flag == 1 ]]; then
        while [ $k -lt $count ]
        do
            sum_rss=`value_at_array "$SUM_RSS_MEM" $k`
            sum_rss=$(expr "$sum_rss" / "$polling_count")
            pid=`value_at_array "$PID_NUM" $k`
            if [ -z $pid ]
            then
                k=$(($k+1))
                continue
            fi
            sum_rss="$sum_rss$kb"
            proc_name=`value_at_array "$PROCESS_NAME" $k`
            log_report "AVG_STACK_$proc_name:" \$sum_rss
            k=$(($k+1))
        done
    fi
    touch Report7
}
echo "*************************STARTING   RDK-B DIAGNOSTIC SCRIT*********************************"
echo ""
echo -e "\tTotal time		:$total_time sec"
echo -e "\tPolling time		:$polling_interval sec"
echo -e "\tUpload		:$upload"
echo -e "\tMode			:$mode"
echo ""
echo "*******************************************************************************************"
rm Report1 Report2 Report3 Report4 Report5 Report6 Report7
echo "**********************************************PS command output**********************************************" >> Report
ps >> Report
if [[ -f /nvram/syscfg.db ]]; then
    echo "**********************************************SYSCONFG output**********************************************" >> Report
    cat /nvram/syscfg.db >> Report
else
    echo "**********************************************syscfg not present**********************************************" >> Report
fi
if [[ -f /nvram/bbhm_cur_cfg.xml ]]; then
    echo "**********************************************BBHM output**********************************************" >> Report
    cat /nvram/bbhm_cur_cfg.xml >> Report
else
    echo "**********************************************bbhm_cur_cfg not present**********************************************" >> Report
fi

if [[ -f /sbin/cfg ]]; then
    echo "**********************************************WiFi-DB output**********************************************" >> Report
    cfg -s >> Report
else
    echo "**********************************************WiFi-DB not present**********************************************" >> Report
fi

echo "**********************************************ifconfig erouter0**********************************************" >> Report
ifconfig erouter0 >> Report


if [[ -f /sbin/iwconfig ]]; then
    echo "iwconfig ath0" >> Report
    iwconfig ath0 >> Report
    echo "iwconfig ath1" >> Report
    iwconfig ath1 >> Report
    echo "iwconfig ath4" >> Report
    iwconfig ath4 >> Report
    echo "iwconfig ath5" >> Report
    iwconfig ath5 >> Report
else
    echo "**********************************************iwconfig not present**********************************************" >> Report
fi
 monitor_cpu_util &
 monitor_load_avg &
 monitor_flash_size &
 monitor_dev_memory_util &
 monitor_proc_memory_util &
 monitor_rss_for_pid &
 monitor_stack_for_pid &
 upload_success=0
 counter=0
 task_done=0
#wait for the Report generation
echo "Checking for all tasks"
counter=0
while : 
do
    if [[ -f Report1 ]]; then
        if [[ -f Report2 ]]; then
            if [[ -f Report3 ]]; then
                if [[ -f Report4 ]]; then
                    if [[ -f Report5 ]]; then
                        if [[ -f Report6 ]]; then
                            if [[ -f Report7 ]]; then
                                task_done=1
				break
                            fi
                        fi
                    fi
                fi
            fi
        fi
    fi
    if [[ $task_done == 1 ]]; then
        break
    fi
    counter=$(($counter+1))
    sleep 60
    echo "Waiting for script to finish execution $counter"
done
echo "All tasks done"

rm Report1 Report2 Report3 Report4 Report5 Report6 Report7
up_time=`uptime | sed 's/.*up \([^,]*\), .*/\1/'`
echo "********************************Finished at $up_time**************************************"
if [[ $task_done == 1 ]]; then
    if [[ $upload == NULL ]]; then
        echo "Report generated successfully!"
        echo "Exitting the script..."
        exit 0
    else
        echo "Starting TFTP upload..."
        upload_success=$(tftp -pr Report $upload)
        upload_success=$?
        if [[ $upload_success == 0 ]]; then
            echo "Upload successful!"
            exit 0
        else
            echo "Failed to upload TFTP Error code: $upload_success"
            exit 1
        fi
    fi
else
    
    if [[ $upload == "NULL" ]]; then
        echo "All tasks did not finish in time"
        exit 2
    else
        echo "All tasks did not finish in time"
        echo "Cannot upload"
        exit 3
    fi
fi
