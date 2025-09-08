#!/bin/bash
# @author:       Juan Morla
# Version:       2.0
# Descripción:
#   Este script verifica el estado de las consolas de administración de Oracle
#   WebLogic Server, listándolas de manera ordenada desde la versión más antigua
#   hasta la más reciente disponible.
#
#   Versiones soportadas:
#     - WebLogic Server 10.3.x
#     - WebLogic Server 12.1.1.3.0
#     - WebLogic Server 12.2.1.4.0
#     - WebLogic Server 14.1.1.0.0
#	  - WebLogic Server	14.1.2.0.0 -> Si el .war WebLogic-Remote-Console no esta 
#						              desplegado las url arrojaran el codigo 300-399 y 404
#
# Uso:
#   ./check_weblogic_console_status_v2.sh
#
#===============================================================================
#
#
#-----Variables_colorsYconf-----#
azul='\033[34m'                 #
red='\033[31m'                  #
verde='\033[32m'                #
null='\033[0m'                  #
negrita='\033[1m'               #
turquesa='\033[36m'             #
magenta='\033[35m'              #
blanco='\033[37m'               #
amarillo='\033[33m'             #
Archivo_conf='Check_02.conf'    #
Codigo_salida="Codigo_http.txt" #
A=0                             #
#-------------------------------#
#
#--------Debugers---------#-----------------------------------#
#set -x                   # descomente para depurar el codigo # 
#-------------------------#-----------------------------------#

#---- Crear ficheros temporales para la información de dominios ---------------#
touch ${Archivo_conf} ${Codigo_salida} &>/dev/null

#---- Función: Filtro de consolas según código HTTP/HTTPS ---------------------#
function Filtro_codigo_http {

	if [[ ${codigo_http} -ge 200 && ${codigo_http} -le 299 ]]; then
    echo -e "${negrita}${blanco}Console:${null} [${negrita}${verde}${console}${null}] ${negrita}${blanco}Puerto:${null} [${negrita}${magenta}${puerto}${null}] ${negrita}${blanco}Codigo_de_status_console:${null} [${negrita}${verde}${codigo_http}${null}]" 
  elif [[ ${codigo_http} -ge 300 && ${codigo_http} -le 399 ]]; then
    echo -e "${negrita}${blanco}Console:${null} [${negrita}${amarillo}${console}${null}] ${negrita}${blanco}Puerto:${null} [${negrita}${magenta}${puerto}${null}] ${negrita}${blanco}Codigo_de_status_console:${null} [${negrita}${amarillo}${codigo_http}${null}]"        
  elif [[ ${codigo_http} -ge 400 && ${codigo_http} -le 599 ]]; then
    echo -e "${negrita}${blanco}Console:${null} [${negrita}${red}${console}${null}] ${negrita}${blanco}Puerto:${null} [${negrita}${magenta}${puerto}${null}] ${negrita}${blanco}Codigo_de_status_console:${null} [${negrita}${red}${codigo_http}${null}]"
  fi

}

#---- Buscar procesos y rutas para generar URLs de AdminServers ----------------#
for PID in $(ps axu |grep AdminServer|grep -v grep|awk '{print $2}')
do
	
	ruta=$(readlink -f /proc/${PID}/fd/* 2>/dev/null | grep AdminServer | head -n1 | sed 's:/servers/AdminServer.*::')

	#--- Generar URLs posibles (http/https, console/rconsole) ---------------------# (Esto debe de ser optimizado en la version v3)
	for Puerto in $(ss -tulnap|grep LISTEN|grep ${PID} |awk '{print $5}'|rev|cut -d: -f 1 |rev|sort|uniq)
	do
		console_http="$(echo ${Puerto}|sed "s|[0-9].*|http://$(hostname):&/console/login/LoginForm.jsp|") ${ruta} ${PID} ${Puerto}" 
		console_https="$(echo ${Puerto}|sed "s|[0-9].*|https://$(hostname):&/console/login/LoginForm.jsp|") ${ruta} ${PID} ${Puerto}" 
		console_rconsole_http="$(echo ${Puerto}|sed "s|[0-9].*|http://$(hostname):&/rconsole/signin/index.html|") ${ruta} ${PID} ${Puerto}" 
		console_rconsole_https="$(echo ${Puerto}|sed "s|[0-9].*|https://$(hostname):&/rconsole/signin/index.html|") ${ruta} ${PID} ${Puerto}" 
		echo -e  "${console_http}\n${console_https}\n${console_rconsole_http}\n${console_rconsole_https}" >>${Archivo_conf}
	done

done

#---- Generar procesos en segundo plano para testear estado de las URLs -------#
while read -r url; do
  {
    #--- Filtrar por SSL y validar estatus de conexión --------------------------#	
    if [[ "$url" =~ ^https ]]; then
      code=$(curl -sIX GET "$url" --insecure 2>/dev/null | grep -E "HTTP/[0-9.]+" | awk '{print $2}')
    else
      code=$(curl -sIX GET "$url" 2>/dev/null | grep -E "HTTP/[0-9.]+" | awk '{print $2}')
    fi

     #--- Guardar resultados válidos en archivo ---------------------------------#
    [[ ${code} -ge 200 && ${code} -le 399 ]] && echo "$(grep -w ${url} ${Archivo_conf}) ${code}" >> "${Codigo_salida}"
	 	[[ ${code} -ge 500 && ${code} -le 599 ]] && echo "$(grep -w ${url} ${Archivo_conf}) ${code}" >> "${Codigo_salida}"
  } & 

done < <(cat $Archivo_conf| cut -d" " -f 1)
wait


#---- Función: Formatear salida final (similar a versión v1) ------------------#
function formatear_linea {

	IFS=$'\n'
	for linea in $(sort -k3,3n ${Codigo_salida}); do

   	console=$(echo $linea|awk '{print $1}')
    home=$(echo $linea|awk '{print $2}')
    pid=$(echo $linea|awk '{print $3}')
    puerto=$(echo $linea|awk '{print $4}')
    codigo_http=$(echo $linea|awk '{print $5}')

		if [[ ${pid_old} != ${pid} ]];then   		
    	echo -e "\n${negrita}${blanco}Path_Domain:${null} [${negrita}${azul}${home}${null}] ${negrita}${blanco}PID:${null} [${negrita}${turquesa}${pid}${null}]" 
    	Filtro_codigo_http
    	A=1
    else
    	Filtro_codigo_http
    fi 	
    pid_old=${pid}
	
	done
	unset IFS 

}

formatear_linea
rm ${Archivo_conf} &>/dev/null ;rm ${Codigo_salida} &>/dev/null


#--------Debugers---------#---------------------------------------------------#
#set -x                   # descomente para finalizar la depuracion del codigo#
#-------------------------#---------------------------------------------------#
