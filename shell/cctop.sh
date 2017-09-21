#!/bin/bash
##################################################
##################################################
#   
#
#
# cctop:  check memory usage on multiple servers
#        usage: cctop -h
#
#
#
# SSH into each server and print total CPU 
# usage (%), total MEM usage (%) and pids 
# which are using MEM >=MEMVAL. CPU usage 
# shows instantaneous usage (i.e. not always accurate)
# and uses mpstat 1 1.
#
# Users should set up passwordless access to 
# all servers being SSHd into via:
#
#     ssh-keygen -t rsa
#     ssh-copy-id -i ~/.ssh/id_rsa.pub user@remote-system
#
# Add following to .bashrc: 
#
#     alias cctop='/dir/to/cctop.sh'
#
#
# Eytan Rocheta
# erocheta@gmail.com
# Version: 1.6
# Date: 9/06/16
#
#  "I think I sprained my brain" -ZZ Top
##################################################
##################################################

# Show pids which are using >= this % total memory (change with -m option)
mem_val=0.25 

# Default username (change with -u option)
username="$USER"

# Default domain (change with -d option)
domain=".ccrc.unsw.edu.au"

##################################################
##################################################

# Server info
slist_A="squall maelstrom blizzard monsoon" 
ncpu_A=16	
nmem_A=256

slist_B="cyclone hurricane typhoon" 
ncpu_B=12
nmem_B=96

##################################################

function usage
{
    echo ""
    echo " Check memory usage on multiple CCRC servers."
    echo " Usage:   cctop [-u zID] [-m mem_val] "
    echo "     e.g. cctop  -u zID 2 squall 4 -o" 
    echo " Missing server argument will default to new servers"
    echo ""
    echo " -u, zID		Change user ID"
    echo " -m, 0.25		Show PIDs using m% of memory"
    echo "                           (0<=m<=100) default m=0.25"
    echo " -a, --all		Show all servers"
    echo " -n, --new		Show new servers" 
    echo " -o, --old		Show old servers" 
    echo " -h, --help		Show this help" 
    echo ""
    echo " Option includes individual server numbers or names:"
    echo " 1: squall                5: cyclone"
    echo " 2: maelstrom             6: hurricane"
    echo " 3: blizzard              7: typhoon"
    echo " 4: monsoon               "
    echo ""
    echo " Output:"
    echo " Name | zID | STATUS | PID | CPU | MEM | MEM % | Runtine (hrs) | Program"
}

#################################################

function print_mem
{
    local server n_cpus n_mem cpu_percent mem_load mem_percent st
    local  fga fgs n1 n2 len i top_flag
    for server in $server_list
    do
      host=$username"@"$server$domain
      #TODO ^^ doesnt work when running from old servers - capilatising issue
	printf '\e[1;34m%-20s\e[m'   "${server^^}" #blue
	
      # select n_cpus and n_mem based on server groups	
	if [[ "${slist_A/$server}" != "${slist_A}" ]];then
	    n_cpus="$ncpu_A"  
	    n_mem="$nmem_A"
          top_flag=" -Mban1" # top -a sorts by mem usage but top -m for old servers. 
	elif [[ "${slist_B/$server}" != "${slist_B}" ]];then
	    n_cpus="$ncpu_B"
	    n_mem="$nmem_B"
          top_flag=" -Mbmn1"
	else
	    echo "Error with choice of server or server lists. Exiting"
	    exit 1
	fi

      # SSH in and get info: CPU, MEM, TOP, FINGER
      cpu_percent=$(ssh "$host" mpstat 1 1  | grep "Average:" | awk '{print $3}') 
      mem_load=$(ssh "$host" free -g | grep "+ buffers/cache" | awk '{print $3}') 
      # 2"x" here so that only one zid field is converted to names below
      st=$(ssh "$host"  top "$top_flag"  | sed '1,6d' | awk ' $10>="'"$mem_val"'" { \
            print $2"x",$2,$8,$1,$9,$5,$10,$11/60,$12 }' )  
      mem_percent=$(bc <<< "scale=3;("$mem_load"/"$n_mem")*100")
      fga=$(echo "$st" | awk ' match($2, /z/){print $2} ') #only finger strings start "z"
      fgs=$(ssh "$host" finger  $fga |  grep  "Name") # unfortunately removes duplicates
      n1=($(echo "$fgs" | awk ' {print $2"x"}')) #an array of zIDs with an appended "x"
      n2=($(echo "$fgs" | awk ' {print $4$5}')) # array of names
      len=$(echo ${n1[*]} | wc -w)
      for i in $(seq 0 $len); do #swap out zIDs with names
            st=${st//${n1[i]}/${n2[i]}}
      done
      
      echo -n "            "
	# print total CPU and MEM usage with colors
	if [ $(printf "%.0f" "$cpu_percent") -ge 70  ]; then
	    printf  '%s \e[1;31m%.4s%s\e[0m'    "CPU:" $cpu_percent "%" #bold red
	elif [  $(printf "%.0f" "$cpu_percent") -ge 50 ]; then
	    printf  '%s \e[31m%.4s%s\e[0m'    "CPU:" $cpu_percent "%" #light red
	else 
	    printf  '%s \e[1;32m%.4s%s\e[0m'    "CPU:" $cpu_percent "%" #green
	fi
	echo -n "     "
	if [ $(printf "%.0f" "$mem_percent") -ge 70 ]; then
	    printf  '%s \e[1;31m%.4s%s\e[0m\n'   "MEM:" $mem_percent "%" #bold red
	elif [ $(printf "%.0f" "$mem_percent") -ge 50 ]; then
	    printf  '%s \e[31m%.4s%s\e[0m\n'   "MEM:" $mem_percent "%" #light red
	else 
	    printf  '%s \e[1;32m%.4s%s\e[0m\n'   "MEM:" $mem_percent "%" #green
	fi

	if [  -n "$st" ]; then #if there are no values do not print empty space
	    printf "%-16.16s %s  %-1s  %-6.6s %-6.6s %-6.6s  %-5.5s  %-4.4s"hrs"  %s\n" $st
	fi

	echo "-----------------------------------------------------------------------------"
    done
}

##################################################

function main
{
    if [[ "$#" -eq 0 ]]; then
	echo ""
	echo "-----------------------------------------------------------------------------"
	server_list="$slist_A" 
	print_mem
	echo ""
	exit
    else
	while [[ "$1" != ""  ]]; do
	    case "$1" in
		-h | --help )
		    usage
		    exit 
               ;;
		-u | -user ) shift
		    username="$1" 
		    ;;
		-m | -mem ) shift
		    mem_val="$1" 
		    ;;
		-d | -dom ) shift
		    domain="$1" 
		    ;;
		1 | squall ) server_list="$server_list squall" 
		    ;;
		2 | maelstrom ) server_list="$server_list maelstrom" 
		    ;;
		3 | blizzard ) server_list="$server_list blizzard" 
		    ;;
		4 | monsoon ) server_list="$server_list monsoon" 
		    ;;
		5 | cyclone ) server_list="$server_list cyclone" 
		    ;;
		6 | hurricane ) server_list="$server_list hurricane" 
		    ;;
		7 | typhoon ) server_list="$server_list typhoon" 
		    ;;
		-n | --new ) server_list="$server_list $slist_A" 
		    ;;
		-o | --old ) server_list="$server_list $slist_B" 
		    ;;
		-a | --all ) server_list="$server_list $slist_A $slist_B" 
		    ;;
		* )	usage
		    exit 1 
		    ;;
	    esac
	    shift
	done

      if [[ -z "$server_list" ]]; then                # if server_list is still empty 
            server_list="$server_list $slist_A"   #(i.e. only opt -m or -u used) 
      fi                                                              #set server_list to default
	echo ""
	echo "-----------------------------------------------------------------------------"
      print_mem #print output with given options
	echo ""

    fi
}

main "$@" 

