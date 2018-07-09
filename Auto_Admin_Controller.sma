/*
* Auto Admin Controller v1.4 by Bl0ck
*
* Плагин для автоматического управления админами сервера.
*
* Основные возможности:
* - Автоматическое снятие админки по окончании срока указаного в users.ini.
* - Добавление админов в users.ini и uaio_admins.ini командами aac_addadmin и addadmin.
* - Удаление админов командой aac_remove и remove_admin.
* - Изменение пароля админки командой amx_pw, доступной для всех админов.
* - Изменение флагов админа командой aac_flags, так же меняет и UAIO flags.
* - Изменение срока админки командой aac_days.
* - Отбирание админки (штраф) командой aac_take на определенный срок.
* - Автоматическое возвращение админки по окончанию срока штрафа.
* - Управление только с IP адресов указаных в кваре aac_ip.
* - Просмотр списка админов командой aac_admins.
*/

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <regex>

#define NEW_YEAR_PODAROR 2018

#define UAIO
#define KRIVBASS

#define STRLEN 150

#define MEGA_ADMIN ADMIN_IMMUNITY|ADMIN_RESERVATION|ADMIN_KICK|ADMIN_BAN|ADMIN_SLAY|ADMIN_MAP|ADMIN_CVAR|ADMIN_CFG|ADMIN_CHAT|ADMIN_VOTE|ADMIN_PASSWORD|ADMIN_RCON|ADMIN_LEVEL_A|ADMIN_LEVEL_B|ADMIN_LEVEL_C|ADMIN_LEVEL_D|ADMIN_LEVEL_E|ADMIN_LEVEL_F|ADMIN_LEVEL_G|ADMIN_LEVEL_H|ADMIN_MENU

new users_file[ 64 ], log_file[ 64 ];
#if defined UAIO
new uaio_file[ 64 ], Array:uaio_users;
#endif
new Array:amxx_users;
new year, month, day;
new days[ 33 ], Array:model_string;
new start_size;
new main_ip[ 128 ];
new lowpriority_ip[ 128 ];

public plugin_init( )
{
	register_plugin( "Auto Admin Controller", "1.5.5", "Bl0ck" );	// 03.02.2016 
	
	register_clcmd( "amx_pw", "change_pw", ADMIN_ADMIN, "<old pass> <new pass> - change password." );
	register_clcmd( "amx_password", "change_pw", ADMIN_ADMIN, "<old pass> <new pass> - change password." );
	register_clcmd( "amx_pass", "change_pw", ADMIN_ADMIN, "<old pass> <new pass> - change password." );

	register_concmd( "aac_admins", "admins_list", MEGA_ADMIN, "- show users.ini." );

#if defined UAIO
	register_concmd( "aac_addadmin", "add_admin", MEGA_ADMIN, "<name|ip> <flags> [duration in days] [password] [player_model] [uaio flags] - add admin." );
	register_concmd( "addadmin", "add_admin", MEGA_ADMIN, "<name|ip> <flags> [duration in days] [password] [player_model] [uaio flags] - add admin." );

	register_concmd( "aac_flags", "admin_flags", MEGA_ADMIN, "<name|ip> [flags] [uaio flags] - show/change admin's flags." );
#else
	register_concmd( "aac_addadmin", "add_admin", MEGA_ADMIN, "<name|ip> <flags> [duration in days] [password] [player_model] - add admin." );
	register_concmd( "addadmin", "add_admin", MEGA_ADMIN, "<name|ip> <flags> [duration in days] [password] [player_model] - add admin." );

	register_concmd( "aac_flags", "admin_flags", MEGA_ADMIN, "<name|ip> [flags] - show/change admin's flags." );
#endif
	register_concmd( "aac_days", "admin_days", MEGA_ADMIN, "<name|ip> [days] - show/change admin's days." );
	
	register_concmd( "aac_remove", "remove_admin", MEGA_ADMIN, "<name|ip> - remove admin." );
	register_concmd( "removeadmin", "remove_admin", MEGA_ADMIN, "<name|ip> - remove admin." );
	register_concmd( "remove_admin", "remove_admin", MEGA_ADMIN, "<name|ip> - remove admin." );

	register_concmd( "amx_offadm", "take_admin", MEGA_ADMIN, "<name|ip> [дни] - take away admin (penalty)." );
	register_concmd( "aac_take", "take_admin", MEGA_ADMIN, "<name|ip> [дни] - take away admin (penalty)." );
	register_concmd( "aac_punish", "take_admin", MEGA_ADMIN, "<name|ip> [дни] - take away admin (penalty)." );
	
	register_concmd( "aac_pause", "take_admin", MEGA_ADMIN, "<name|ip> [дни] - take away admin (penalty)." );
	register_concmd( "aac_penalty", "take_admin", MEGA_ADMIN, "<name|ip> [дни] - take away admin (penalty)." );
	
	register_concmd( "aac_pw", "admin_pw", MEGA_ADMIN, "<name|ip> <new password> - show/change admin password." );

	register_concmd( "aac_login", "admin_login", MEGA_ADMIN, "<name|ip> <new name|ip> - show/change name|ip." );
	register_concmd( "aac_name", "admin_login", MEGA_ADMIN, "<name|ip> <new name|ip> - show/change name|ip." );
	register_concmd( "aac_nick", "admin_login", MEGA_ADMIN, "<name|ip> <new name|ip> - show/change name|ip." );
	
	register_concmd( "aac_model", "admin_model", MEGA_ADMIN, "<name|ip> [player_model] - show/change admin's player_model." );
	
	register_srvcmd( "aac_ip", "set_main_ip" );
	register_srvcmd( "aac_ip_low", "set_lowpriority_ip" );
}

public plugin_natives( )
{
	register_library( "aac" );
	register_native( "get_admin_days", "get_admin_days", 1 );
}

public set_main_ip( )
{
	read_argv( 1, main_ip, 127 );
}

public set_lowpriority_ip( )
{
	read_argv( 1, lowpriority_ip, 127 );
}

public plugin_precache( )
{
	new dir[ 33 ];
	get_configsdir( dir, 32 );
	format( users_file, 63, "%s/users.ini", dir );
#if defined UAIO
	format( uaio_file, 63, "%s/uaio/uaio_admins.ini", dir );
	uaio_users = ArrayCreate( STRLEN );
#endif
	
	date( year, month, day );
	
	amxx_users = ArrayCreate( STRLEN );
	
	model_string = ArrayCreate( 1 );

	get_localinfo( "amxx_logs", log_file, 63 );
	format( log_file, 63, "%s/aac", log_file );

	if( !dir_exists( log_file ) )
		mkdir( log_file );
	
	format( log_file, 63, "%s/aac_%d_%s%d.log", log_file, year, month < 10 ? "0" : "", month );
	
	load_file( );

	static i, str[ STRLEN ], model[ 78 ];

	for( i = 0; i < ArraySize( amxx_users ); i++ )
	{
		ArrayGetString( amxx_users, i, str, STRLEN-1 );
		if( str[ 0 ] == ';' || str[ 0 ] == '/' || !str[ 0 ] )
			continue;
		
		parse( str, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, model, 32 );
	
		if( model[ 0 ] )
		{
			ArrayPushCell( model_string, i );
	
			format( model, 77, "models/player/%s/%s.mdl", model, model );
			if( file_exists( model ) )
				precache_model( model );
			else
				continue;
			
			format( model[ strlen( model ) - 4 ], 77, "T.mdl" );
			if( file_exists( model ) )
				precache_model( model );
		}
	}
}

forward deathrun_playerrespawn( id, team, flags );

public deathrun_playerrespawn( id, team, flags )
{
	if( !( flags & ADMIN_LEVEL_D ) || team != 2 ) /* flag "p" */
		return;

	if( !ArraySize( model_string ) )
		return;

	static name[ 32 ], ip[ 32 ], steam[ 32 ], first[ 32 ], model[ 32 ], str[ STRLEN ], i;
	get_user_name( id, name, 31 );
	get_user_ip( id, ip, 31, 1 );
	get_user_authid( id, steam, 31 );

	for( i = 0; i < ArraySize( model_string ); i++ )
	{
		ArrayGetString( amxx_users, ArrayGetCell( model_string, i ), str, STRLEN-1 );

		parse( str, first, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, model, 32 );
		if( equal( first, name ) || equal( first, ip ) || equal( first, steam ) )
		{
			cs_set_user_model( id, model );
			break;
		}
	}
}

public take_admin( id, level, cid )
{
	if( !cmd_access( id, level, cid, 2 ) || ( !equal_main_ip( id ) && !equal_lowpriority_ip( id ) ) )
		return PLUGIN_HANDLED;

	new data[ 33 ], days[ 33 ];
	read_argv( 1, data, 32 );
	read_argv( 2, days, 32 );

	if( start_size != file_size( users_file ) )
		load_file( );

	new line = find_admin( data );

	if( line == -2 )
	{
		console_print( id, "[AAC] Found more than two results." );
		return PLUGIN_HANDLED;
	}
	else if( line == -1 )
	{
		console_print( id, "[AAC] Not found." );
		return PLUGIN_HANDLED;
	}

	new first[ 33 ], gdate[ 18 ], str[ STRLEN ], access[ 24 ], no;
	ArrayGetString( amxx_users, line, str, STRLEN-1 );
	parse( str, first, 32, 0, 0, access, 23, 0, 0, 0, 0, gdate, 17 );
	if( first[ 0 ] == ';' )
		no = 1;
	new dayz = date_to_num( gdate );
	new p_flags[ 10 ];
	if( gdate[ 10 ] )
	{
		format( p_flags, 9, gdate[ 10 ] );
		gdate[ 10 ] = 0;
	}
	if( !isdigit( days[ 0 ] ) || ( !gdate[ 0 ] && days[ 0 ] == '0' && !no ) )
	{
		console_print( id, "[AAC] Admin %s penalty until: %s - %d days", first[ no ], gdate, dayz );
		return PLUGIN_HANDLED;
	}
	else
	{
		new newdays = str_to_num( days );
		new fdate[ 18 ];
		num_to_date( newdays, fdate );
		
		new command[ 33 ], bool:only_adm_punish = true, adms_flags[ 8 ];
		read_argv( 0, command, 32 );
		
		if( equali( command[ 4 ], "penalty", 7 ) || equali( command[ 4 ], "pause", 5 ) )
			only_adm_punish = false;

		if( only_adm_punish && check_for_adm_flags( access, strlen( access ), adms_flags ) )
		{
			format( fdate, 17, "%s%s", fdate, adms_flags );
			change_param( line, access, 3 );
			change_param( line, fdate, 6 );
		}
		else
		{
			if( p_flags[ 0 ] )
				format( fdate, 17, "%s%s", fdate, p_flags );
			change_param( line, fdate, 6 );
			if( str[ 0 ] != ';' )
				change_param( line, ";", 0 );
		}
		
		if( newdays <= 0 )
			check_admins_days( );
		
#if defined UAIO
		line = find_uaio_admin( data );
		if( line > 0 )
		{
			ArrayGetString( uaio_users, line, str, STRLEN-1 );
			if( str[ 0 ] != ';' && newdays > 0 )
			{
				format( str, STRLEN-1, ";%s", str );
				ArraySetString( uaio_users, line, str );
			}
	
			write_uaio_admins( );
		}
		write_uaio_admins( );
#endif

		write_admins( );
		set_task( 1.0, "reload_admins" );

		if( newdays > 0 )
		{
			console_print( id, "[AAC] Вы забрали админку у %s на %d дней", first[ no ], newdays );
			aac_log( id, "забрал админку у ^"%s^" на %d дней", first[ no ], newdays );
		}
		else
		{
			console_print( id, "[AAC] Вы вернули админку %s", first[ no ] );
			aac_log( id, "вернул админку ^"%s^"", first[ no ] );
		}
		
		new player = find_player( "a", first[ no ] );
		if( !player )
			player = find_player( "d", first[ no ] );

		if( player && id )
		{
			static name[ 33 ], pl_name[ 33 ];
			get_user_name( id, name, 32 );
			get_user_name( player, pl_name, 32 );
			if( newdays > 0 )
				client_print( 0, print_chat, "[AAC] %s забрал админку у ^"%s^" на срок %d дней.", name, pl_name, newdays );
			else
				client_print( 0, print_chat, "[AAC] %s вернул админку ^"%s^".", name, pl_name );
		}
		
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_HANDLED;
}

check_for_adm_flags( access[ ], len, adm_flags[ ] )
{
	new i, adms, nots;
	for( i = 0; i < len; i++ )
	{
		if( access[ i ] == 'a' || access[ i ] == 'b' || access[ i ] == 'c' )
		{
			adm_flags[ adms++ ] = access[ i ];
			access[ i ] = ' ';
		}
		else
			nots++;
	}
	trim( access );
	return adms && nots ? 1 : 0;
}

public remove_admin( id, level, cid )
{
	if( !cmd_access( id, level, cid, 2 ) || !equal_main_ip( id ) )
		return PLUGIN_HANDLED;

	new data[ 33 ];
	read_argv( 1, data, 32 );

	if( start_size != file_size( users_file ) )
		load_file( );

	new line = find_admin( data );

	if( line == -2 )
	{
		console_print( id, "[AAC] Found more than two results." );
		return PLUGIN_HANDLED;
	}
	else if( line == -1 )
	{
		console_print( id, "[AAC] Not found." );
		return PLUGIN_HANDLED;
	}

	new first[ 33 ], pass[ 33 ], flags[ 33 ], date[ 11 ], str[ STRLEN ];
	ArrayGetString( amxx_users, line, str, STRLEN-1 );
	parse( str, first, 32, pass, 32, flags, 32, 0, 0, date, 10 );
	if( first[ 0 ] == ';' )
		replace( first, 32, ";", "" );
	
	ArrayDeleteItem( amxx_users, line );

#if defined UAIO
	line = find_uaio_admin( data );
	if( line > 0 )
	{
		ArrayDeleteItem( uaio_users, line );
		write_uaio_admins( );
	}
#endif

	write_admins( );
	set_task( 1.0, "reload_admins" );
	console_print( id, "[AAC] Вы удалили админа %s", first );
	aac_log( id, "удалил админа ^"%s^" ^"%s^" ^"%s^" ^"%s^"", first, pass, flags, date );

	new player = find_player( "a", first );
	if( !player )
		player = find_player( "d", first );

	if( player && id )
	{
		static name[ 33 ], pl_name[ 33 ];
		get_user_name( id, name, 32 );
		get_user_name( player, pl_name, 32 );
		client_print( 0, print_chat, "[AAC] %s удалил админа ^"%s^".", name, pl_name );
	}

	return PLUGIN_HANDLED;
}

public admin_days( id, level, cid )
{
	if( !cmd_access( id, level, cid, 2 ) || !equal_main_ip( id ) )
		return PLUGIN_HANDLED;

	new data[ 33 ], days[ 33 ];
	read_argv( 1, data, 32 );
	read_argv( 2, days, 32 );

	if( start_size != file_size( users_file ) )
		load_file( );

	new line = find_admin( data );

	if( line == -2 )
	{
		console_print( id, "[AAC] Found more than two results." );
		return PLUGIN_HANDLED;
	}
	else if( line == -1 )
	{
		console_print( id, "[AAC] Not found." );
		return PLUGIN_HANDLED;
	}

	new first[ 33 ], gdate[ 11 ], access[ 24 ], str[ STRLEN ];
	ArrayGetString( amxx_users, line, str, STRLEN-1 );
	parse( str, first, 32, 0, 0, access, 23, 0, 0, gdate, 10 );
	if( first[ 0 ] == ';' )
		replace( first, 32, ";", "" );
	new dayz = date_to_num( gdate );
	if( !isdigit( days[ 0 ] ) )
	{
		console_print( id, "[AAC] Admin '%s' flags '%s' until: %s - %d days", first, access, gdate, dayz );
		return PLUGIN_HANDLED;
	}
	else
	{
		new newdays = str_to_num( days );
		if( days[ 0 ] == '-' )
			newdays = dayz - newdays;
		else if( days[ 0 ] == '+' )
			newdays = dayz + newdays;

		new fdate[ 11 ];
		num_to_date( newdays, fdate );
		
		change_param( line, fdate, 5 );
		write_admins( );
		set_task( 1.0, "reload_admins" );
		console_print( id, "[AAC] Вы установили админу %s: %d дней", first, newdays );
		aac_log( id, "изменил дни админа ^"%s^" с %d на %d", first, dayz, newdays );
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_HANDLED;
}

public admin_model( id, level, cid )
{
	if( !cmd_access( id, level, cid, 2 ) || !equal_main_ip( id ) )
		return PLUGIN_HANDLED;

	new data[ 33 ], model[ 33 ];
	read_argv( 1, data, 32 );
	read_argv( 2, model, 32 );

	if( start_size != file_size( users_file ) )
		load_file( );

	new line = find_admin( data );

	if( line == -2 )
	{
		console_print( id, "[AAC] Found more than two results." );
		return PLUGIN_HANDLED;
	}
	else if( line == -1 )
	{
		console_print( id, "[AAC] Not found." );
		return PLUGIN_HANDLED;
	}

	new first[ 33 ], oldmodel[ 33 ], str[ STRLEN ];
	ArrayGetString( amxx_users, line, str, STRLEN-1 );
	parse( str, first, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, oldmodel, 32 );
	if( first[ 0 ] == ';' )
		replace( first, 32, ";", "" );

	if( !model[ 0 ] )
	{
		console_print( id, "[AAC] У %s player_model: ^"%s^"", first, oldmodel );
		return PLUGIN_HANDLED;
	}
	else
	{
		change_param( line, model, 7 );
		write_admins( );
		set_task( 1.0, "reload_admins" );
		console_print( id, "[AAC] Вы установили админу %s player_model: ^"%s^"", first, model );
		aac_log( id, "изменил player_model админа ^"%s^" с ^"%s^" на ^"%s^"", first, oldmodel, model );
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_HANDLED;
}

public admin_pw( id, level, cid )
{
	if( !cmd_access( id, level, cid, 2 ) || !equal_main_ip( id ) )
		return PLUGIN_HANDLED;

	new data[ 33 ], pass[ 33 ];
	read_argv( 1, data, 32 );
	read_argv( 2, pass, 32 );

	if( start_size != file_size( users_file ) )
		load_file( );

	new line = find_admin( data );

	if( line == -2 )
	{
		console_print( id, "[AAC] Found more than two results." );
		return PLUGIN_HANDLED;
	}
	else if( line == -1 )
	{
		console_print( id, "[AAC] Not found." );
		return PLUGIN_HANDLED;
	}

	new first[ 33 ], oldpass[ 33 ], str[ STRLEN ];
	ArrayGetString( amxx_users, line, str, STRLEN-1 );
	parse( str, first, 32, oldpass, 32 );
	if( first[ 0 ] == ';' )
		replace( first, 32, ";", "" );

	if( !pass[ 0 ] )
	{
		console_print( id, "[AAC] У %s password: ^"%s^"", first, oldpass );
		return PLUGIN_HANDLED;
	}
	else
	{
		change_param( line, pass, 2 );
		write_admins( );
		set_task( 1.0, "reload_admins" );
		console_print( id, "[AAC] Вы установили админу %s password: ^"%s^"", first, pass );
		aac_log( id, "изменил password админа ^"%s^" с ^"%s^" на ^"%s^"", first, oldpass, pass );
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_HANDLED;
}

public admin_login( id, level, cid )
{
	if( !cmd_access( id, level, cid, 2 ) || !equal_main_ip( id ) )
		return PLUGIN_HANDLED;

	new data[ 33 ], new_data[ 33 ];
	read_argv( 1, data, 32 );
	read_argv( 2, new_data, 32 );

	if( start_size != file_size( users_file ) )
		load_file( );

	new line = find_admin( data );

	if( line == -2 )
	{
		console_print( id, "[AAC] Found more than two results." );
		return PLUGIN_HANDLED;
	}
	else if( line == -1 )
	{
		console_print( id, "[AAC] Not found." );
		return PLUGIN_HANDLED;
	}

	new first[ 33 ], str[ STRLEN ];
	ArrayGetString( amxx_users, line, str, STRLEN-1 );
	parse( str, first, 32 );
	if( first[ 0 ] == ';' )
		replace( first, 32, ";", "" );

	if( !new_data[ 0 ] )
	{
		console_print( id, "[AAC] %s", first );
		return PLUGIN_HANDLED;
	}
	else
	{
		if( regex_check_ip( new_data ) )
			change_param( line, "de", 4 );
		else if( equal( new_data, "STEAM", 5 ) )
			change_param( line, "ce", 4 );
		else
			change_param( line, "a", 4 );

		change_param( line, new_data, 1 );
		write_admins( );
		
#if defined UAIO
		line = find_uaio_admin( data );
		if( line > 0 )
		{
			ArrayGetString( uaio_users, line, str, STRLEN-1 );
			replace( str, STRLEN-1, first, new_data );
			ArraySetString( uaio_users, line, str );
			write_uaio_admins( );
		}
#endif

		set_task( 1.0, "reload_admins" );
		console_print( id, "[AAC] Вы установили админу %s name: ^"%s^"", first, new_data );
		aac_log( id, "изменил name админа с ^"%s^" на ^"%s^"", first, new_data );
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_HANDLED;
}

public admin_flags( id, level, cid )
{
	if( !cmd_access( id, level, cid, 2 ) || !equal_main_ip( id ) )
		return PLUGIN_HANDLED;

	new data[ 33 ], newflags[ 33 ];
#if defined UAIO
	new uaio[ 33 ];
#endif
	read_argv( 1, data, 32 );
	read_argv( 2, newflags, 32 );

	if( start_size != file_size( users_file ) )
		load_file( );

	new line = find_admin( data );

	if( line == -2 )
	{
		console_print( id, "[AAC] Found more than two results." );
		return PLUGIN_HANDLED;
	}
	else if( line == -1 )
	{
		console_print( id, "[AAC] Not found." );
		return PLUGIN_HANDLED;
	}

	new first[ 33 ], access[ 24 ], date[ 11 ], gdate[ 18 ], str[ STRLEN ];
	ArrayGetString( amxx_users, line, str, STRLEN-1 );
	parse( str, first, 32, 0, 0, access, 23, 0, 0, date, 10, gdate, 17 );
	if( first[ 0 ] == ';' )
		replace( first, 32, ";", "" );
	if( !newflags[ 0 ] )
	{
		console_print( id, "[AAC] Admin '%s' flags: '%s %s' and days '%s'", first, gdate[ 10 ], access, date );
		return PLUGIN_HANDLED;
	}
	else
	{
		change_param( line, newflags, 3 );

#if defined UAIO
#if defined KRIVBASS
		if( containi( newflags, "c" ) != -1 )
			uaio = "voteA goodA evilA miscA";
		else if( containi( newflags, "b" ) != -1 )
			uaio = "voteB goodB evilB miscB";
#else
		read_argv( 3, uaio, 32 );
#endif
		if( uaio[ 0 ] )
		{
			line = find_uaio_admin( data );
			if( line > 0 )
			{
				ArrayGetString( uaio_users, line, str, STRLEN-1 );
				format( str, STRLEN-1, "admin ^"%s^" ^"%s^"", first, uaio );
				ArraySetString( uaio_users, line, str );
				write_uaio_admins( );
			}
			else
			{
				format( str, STRLEN-1, "admin ^"%s^" ^"%s^"", first, uaio );
				write_file( uaio_file, str );
			}
		}
#endif
		write_admins( );
		set_task( 1.0, "reload_admins" );
		console_print( id, "[AAC] Вы заменили flags админа %s: с %s на %s", first, access, newflags );
		aac_log( id, "заменил flags админа ^"%s^" с %s на %s", first, access, newflags );
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_HANDLED;
}

public add_admin( id, level, cid )
{
	if( !cmd_access( id, level, cid, 3 ) || !equal_main_ip( id ) )
		return PLUGIN_HANDLED;

	new data[ 33 ], flags[ 33 ], pass[ 33 ], flags2[ 3 ], days[ 4 ], model[ 33 ];
#if defined UAIO
	new uaio[ 33 ];
#endif
	read_argv( 1, data, 32 );
	
	new line = find_admin( data, 0 ), access[ 24 ];
	if( line != -1 )
	{
		new first[ 33 ], str[ STRLEN ];
		ArrayGetString( amxx_users, line, str, STRLEN-1 );
		parse( str, first, 32, 0, 0, access, 23 );
		console_print( id, "[AAC] Админ %s уже есть... Добавляем...", first );
		if( str[ 0 ] != ';' )
			change_param( line, ";", 0 );
		write_admins( );
	}
	
	read_argv( 2, flags, 32 );
	read_argv( 3, days, 3 );
	
	if( !days[ 0 ] )
		days = "30";
	
	days[ 0 ] = str_to_num( days );

	new player;
	if( regex_check_ip( data ) )
	{
		flags2 = "de";
		player = find_player( "d", data );
	}
	else if( equal( data, "STEAM", 5 ) )
	{
		flags2 = "ce";
		player = find_player( "c", data );
	}
	else
	{
		read_argv( 4, pass, 32 );
		if( !pass[ 0 ] )
			flags2 = "e";
		else
			flags2 = "a";
		
		player = find_player( "a", data );
#if defined NEW_YEAR_PODAROR
		log_to_file("adm_podarki2018.log", data);		// новогодний подарок
#endif
	}
	
	read_argv( 5, model, 32 );

#if defined UAIO
#if defined KRIVBASS
	if( flags[ 2 ] == 'c' )
		uaio = "voteA goodA evilA miscA";
	else if( flags[ 1 ] == 'b' )
		uaio = "voteB goodB evilB miscB";
#else
	read_argv( 6, uaio, 32 );
#endif
#endif

	if( access[ 0 ] )
		format( flags, 32, "%s%s", flags, access );

	new amxx_full[ 96 ], fdate[ 11 ];
	num_to_date( days[ 0 ], fdate );
	format( amxx_full, STRLEN-1, "^"%s^" ^"%s^" ^"%s^" ^"%s^" ^"%s^" ^"%s^"", data, pass, flags, flags2, fdate, model );
	write_file( users_file, amxx_full );
#if defined UAIO
	if( uaio[ 0 ] && file_exists( uaio_file ) )
	{
		new uaio_full[ 96 ];
		format( uaio_full, STRLEN-1, "admin ^"%s^" ^"%s^"", data, uaio );
		write_file( uaio_file, uaio_full );
	}
#endif
	console_print( id, "[AAC] Вы добавили админа ^"%s^" на срок %d дней.", data, days[ 0 ] );
	aac_log( id, "добавил админ ^"%s^" ^"%s^" ^"%s^" ^"%s^" на срок %d дней.", data, pass, flags, model, days[ 0 ] );
	if( player && id )
	{
		new name[ 33 ], pl_name[ 33 ];
		get_user_name( id, name, 32 );
		get_user_name( player, pl_name, 32 );
		client_print( 0, print_chat, "[AAC] %s добавил админа ^"%s^" на срок %d дней.", name, pl_name, days[ 0 ] );
	}
	set_task( 1.0, "reload_admins" );
	set_task( 0.5, "load_file" );
	
	return PLUGIN_HANDLED;
}

public admins_list( id, level, cid )
{
	if( !cmd_access( id, level, cid, 1 ) || !equal_main_ip( id ) )
		return PLUGIN_HANDLED;

	static i, str[ STRLEN ], count;
	count = 0;

	for( i = 0; i < ArraySize( amxx_users ); i++ )
	{
		ArrayGetString( amxx_users, i, str, STRLEN-1 );
		if( str[ 0 ] )
		{
			count++;
			console_print( id, str );
		}
	}

	console_print( id, "Count: %d", count );

	return PLUGIN_HANDLED;
}

public get_admin_days( id )
{
	if( days[ id ] )
		return days[ id ];

	static name[ 32 ], ip[ 32 ], steam[ 32 ], i, first[ 33 ], date[ 11 ], str[ STRLEN ];
	get_user_name( id, name, 31 );
	get_user_ip( id, ip, 31, 1 );
	get_user_authid( id, steam, 31 );

	for( i = 0; i < ArraySize( amxx_users ); i++ )
	{
		ArrayGetString( amxx_users, i, str, STRLEN-1 );
		if( str[ 0 ] == '/' || !str[ 0 ] )
			continue;
		
		parse( str, first, 32, 0, 0, 0, 0, 0, 0, date, 10 );
		if( first[ 0 ] == ';' )
			replace( first, 32, ";", "" );
		if( equal( first, name ) || equal( first, ip ) || equal( first, steam ) )
			return days[ id ] = date_to_num( date );
	}
	
	return 0;
}

public change_pw( id, level, cid )
{
	if( !cmd_access( id, level, cid, 3 ) )
		return PLUGIN_HANDLED;

	new name[ 33 ], arg[ 33 ], arg2[ 33 ], find, i, str[ STRLEN ], first[ 33 ], pass[ 33 ];
	read_argv( 1, arg, 32 );
	read_argv( 2, arg2, 32 );
	get_user_name( id, name, 32 );

	if( start_size != file_size( users_file ) )
		load_file( );

	for( i = 0; i < ArraySize( amxx_users ); i++ )
	{
		ArrayGetString( amxx_users, i, str, STRLEN-1 );
		if( str[ 0 ] == ';' || str[ 0 ] == '/' )
			continue;

		parse( str, first, 32, pass, 32 );
		if( equal( first, name ) && equal( pass, arg ) )
		{
			change_param( i, arg2, 2 );
			find = i;
			break;
		}
	}

	if( !find )
	{
		console_print( id, "[AAC] Ваш name не найден в users.ini или старый password введен не верно!" )
		return PLUGIN_HANDLED
	}

	client_cmd( id, "setinfo _pw ^"%s^"", arg2 );

	write_admins( );

	console_print( id, "[AAC] password изменен на ^"%s^"", arg2 );
	client_print( id, print_center, "[AAC] password изменен на ^"%s^"", arg2 );
	aac_log( id, "изменил password с ^"%s^" на ^"%s^"", arg, arg2 );
	
	set_task( 0.5, "reload_admins" );

	return PLUGIN_HANDLED;
}

public write_admins( )
{
	if( !file_exists( users_file ) )
		return PLUGIN_CONTINUE;

	static file, i, str[ STRLEN ];
	file = fopen( users_file, "w" );
	for( i = 0; i < ArraySize( amxx_users ); i++ )
	{
		ArrayGetString( amxx_users, i, str, STRLEN-1 );
		if( str[ 0 ] )
			fprintf( file, "%s^n", str );
	}

	fclose( file );

	return PLUGIN_CONTINUE;
}

#if defined UAIO
public write_uaio_admins( )
{
	if( !file_exists( uaio_file ) )
		return PLUGIN_CONTINUE;
	
	static file, i, str[ STRLEN ];
	file = fopen( uaio_file, "w" );
	for( i = 0; i < ArraySize( uaio_users ); i++ )
	{
		ArrayGetString( uaio_users, i, str, STRLEN-1 );
		if( str[ 0 ] )
			fprintf( file, "%s^n", str );
	}

	fclose( file );

	return PLUGIN_CONTINUE;
}
#endif

public reload_admins( )
{
	server_cmd( "amx_reloadadmins" );
#if defined KRIVBASS
	server_cmd( "uaio_reloadadmins" );
#endif
}

public load_file( )
{
	new len, line, str[ STRLEN ];
	if( file_exists( users_file ) )
	{
		if( start_size )
			ArrayClear( amxx_users );
	
		while( ( line = read_file( users_file, line, str, STRLEN-1, len ) ) )
		{
			if( !len )
				continue;
			
			ArrayPushString( amxx_users, str );
		}
	}
	
#if defined UAIO
	if( file_exists( uaio_file ) )
	{
		if( start_size )
			ArrayClear( uaio_users );

		line = 0;
		while( ( line = read_file( uaio_file, line, str, STRLEN-1, len ) ) )
		{
			if( !len )
				continue;
			
			ArrayPushString( uaio_users, str );
		}
	}
#endif

	if( !start_size )
	{
		if( check_admins_days( ) )
		{
			write_admins( );
#if defined UAIO
			write_uaio_admins( );
#endif
			set_task( 2.0, "reload_admins" );
		}
	}
	
	start_size = file_size( users_file );
}

public client_connect( id )
{
	days[ id ] = 0;
}

public client_infochanged( id )
{
	days[ id ] = 0;
}

public client_disconnect( id )
{
	days[ id ] = 0;
}

aac_log( id, const msg[ ], any:... )
{
	static message[ 192 ]
	new prefix[ 44 ];
	vformat( message, 191, msg, 3 );
	if( id == 0 )
		format( prefix, 43, "Сервер " );
	else if( id != -1 )
	{
		static name[ 33 ];
		get_user_name( id, name, 32 );
		format( prefix, 43, "Админ %s: ", name );
	}
	
	log_to_file( log_file, "%s%s", prefix, message );
}

visokos(year)
{
	return (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0));
}

get_days_in_month( m, y )
{
	while (m > 12)
		m -= 12, y--;
	switch( m )
	{
		case 1: return 31; // january
		case 2: return visokos( y ) ? 29 : 28; // february
		case 3: return 31; // march
		case 4: return 30; // april
		case 5: return 31; // may
		case 6: return 30; // june
		case 7: return 31; // july
		case 8: return 31; // august
		case 9: return 30; // september
		case 10: return 31; // october
		case 11: return 30; // november
		case 12: return 31; // december
	}
	
	return 30;
}

equal_main_ip( id )
{
	if( !id )
		return 1;
	if( !main_ip[ 0 ] )
		return 0;

	new ip[ 22 ], onezero[ 22 ], twozero[ 22 ];
	get_user_ip( id, ip, 21, 1 );
	ip_to_subnet( ip, sizeof( ip ) - 1, onezero, twozero );
	if( contain( main_ip, ip ) != -1 || contain( main_ip, onezero ) != -1 || contain( main_ip, twozero ) != -1 )
		return 1;

	return 0;
}

equal_lowpriority_ip( id )
{
	if( !id )
		return 1;
	if( !lowpriority_ip[ 0 ]  )
		return 0;

	new ip[ 22 ], onezero[ 22 ], twozero[ 22 ];
	get_user_ip( id, ip, 21, 1 );
	ip_to_subnet( ip, 21, onezero, twozero );
	if( contain( lowpriority_ip, ip ) != -1 || contain( lowpriority_ip, onezero ) != -1 || contain( lowpriority_ip, twozero ) != -1 )
		return 1;

	return 0;
}

ip_to_subnet( ip[ ], len, onezero[ ], twozero[ ] )
{
	new i, found;
	for( i = 0; i < len; i++ )
	{
		if( ip[ i ] == '.' )
			found++;
		else
			continue;

		if( found == 2 )
		{
			format( onezero, len, ip );
			format( onezero[ i ], len, ".0.0" );
		}
		else if( found == 3 )
		{
			format( twozero, len, ip );
			format( twozero[ i ], len, ".0" );
		}
	}
}

check_admins_days( )
{
	static cleared, i, str[ STRLEN ], first[ 33 ], access[ 24 ], date[ 11 ], falldate[ 18 ];
#if defined UAIO
	new uaio_first[ 33 ], j;
#endif
	cleared = 0;
	for( i = 0; i < ArraySize( amxx_users ); i++ )
	{
		ArrayGetString( amxx_users, i, str, STRLEN-1 );
		if( str[ 0 ] == '/' || !str[ 0 ] )
			continue;
		
		new bool:no;
		parse( str, first, 32, 0, 0, access, 23, 0, 0, date, 10, falldate, 17 );
		new dayz = date_to_num( date );
		if( first[ 0 ] == ';' )
			replace( first, 32, ";", "" );
	
		if( dayz <= 0 )
		{
#if defined UAIO
			for( j = 0; j < ArraySize( uaio_users ); j++ )
			{
				ArrayGetString( uaio_users, j, str, STRLEN-1 );
				if( str[ 0 ] == '/' || !str[ 0 ] )
					continue;
			
				parse( str, 0, 0, uaio_first, 32 );
				if( equal( uaio_first, "default" ) )
					continue;
					
				if( equal( uaio_first, first ) )
				{
					ArrayDeleteItem( uaio_users, j );
					break;
				}
			}
#endif
			
			new line = find_admin( first, 0, i );
			if( line > -1 )
			{
				new newflags[ 24 ], str[ STRLEN ];
				ArrayGetString( amxx_users, line, str, STRLEN-1 );
				parse( str, 0, 0, 0, 0, newflags, 23 );
				new len = strlen( access ), lenf = strlen( newflags );
				if( lenf > len )
				{
					for( new k = 0; k < len; k++ )
						replace( newflags, 23, access[ k ], "" );
					change_param( line, newflags, 3 );
					change_param( line, "", 0 );
				}
			}

			ArrayDeleteItem( amxx_users, i );
			aac_log( -1, "У ^"%s^" (flags: %s) закончилась админка.", first, access );
			
			cleared++;
			no = true;
		}
		
		if( no || !falldate[ 0 ] )
			continue;
			
		new falldayz = date_to_num( falldate );
		
		if( falldayz <= 0 )
		{
#if defined UAIO
			for( j = 0; j < ArraySize( uaio_users ); j++ )
			{
				ArrayGetString( uaio_users, j, str, STRLEN-1 );
				if( str[ 0 ] == '/' || !str[ 0 ] )
					continue;
			
				parse( str, 0, 0, uaio_first, 32 );
				if( equal( uaio_first, "default" ) )
					continue;
					
				if( equal( uaio_first, first ) )
				{
					replace( str, STRLEN-1, ";", "" );
					ArraySetString( uaio_users, j, str );
					break;
				}
			}
#endif
			if( falldate[ 10 ] )
			{
				format( access, 23, "%s%s", falldate[ 10 ], access );
				change_param( i, access, 3 );
			}
			change_param( i, "", 0 );
			change_param( i, "", 6 );
			aac_log( -1, "У ^"%s^" (%s) закончился штраф админки.", first, falldate );
			
			cleared++;
		}
	}
	
	return cleared;
}

find_admin( name[ ], equalb = 2, linef = -1 )
{
	new line = -1, find = 0, numero = 0;
	static i, str[ STRLEN ], first[ 33 ];
	if( equalb == 2 )
	{
		if( name[ 0 ] == '*' ) equalb = 1;
		if( name[ 1 ] == '.' )
		{
			numero = str_to_num( name[ 0 ] );
			format( name, 32, name[ 2 ] );
		}
	}
	
	for( i = 0; i < ArraySize( amxx_users ); i++ )
	{
		ArrayGetString( amxx_users, i, str, STRLEN-1 );
		if( str[ 0 ] == '/' )
			continue;

		parse( str, first, 32 );
		if( equalb == 2 && containi( first, name ) != -1 || equal( first, name[ equalb ] ) )
		{
			find++;
			line = i;
			if( linef != i && linef != -1 || numero == find )
				return line;
		}
	}

	if( find > 1 )
		return -2;

	if( linef == i )
		return -1;
	
	return line;
}

#if defined UAIO
find_uaio_admin( const name[ ], equalb = 2 )
{
	new line, find = 0;
	static i, str[ STRLEN ], first[ 33 ];
	if( equalb == 2 )
		if( name[ 0 ] == '*' ) equalb = 1;
	for( i = 0; i < ArraySize( uaio_users ); i++ )
	{
		ArrayGetString( uaio_users, i, str, STRLEN-1 );
		if( str[ 0 ] == '/' )
			continue;
		
		parse( str, 0, 0, first, 32 );
		if( equalb == 2 && containi( first, name ) != -1 || equal( first, name[ equalb ] ) )
		{
			find++;
			line = i;
		}
	}

	if( find > 1 )
		return -1;

	return line;
}
#endif

date_to_num( const date[ ] )
{
	new lday[ 3 ], lmonth[ 3 ], lyear[ 5 ];
	format( lday, 2, date[ 0 ], date[ 1 ] );
	format( lmonth, 2, date[ 3 ], date[ 4 ] );
	format( lyear, 4, date[ 6 ], date[ 7 ], date[ 8 ], date[ 9 ] );
	
	lday[ 0 ] = str_to_num( lday ) - day;
	lmonth[ 0 ] = str_to_num( lmonth );
	lyear[ 0 ] = str_to_num( lyear );

	while( year < lyear[ 0 ] )
	{
		lmonth[ 0 ] += 12;
		lyear[ 0 ]--;
	}
	
	while( month < lmonth[ 0 ] )
	{
		new lastmonth = lmonth[ 0 ] - 1;
		lday[ 0 ] += get_days_in_month( lastmonth > 0 ? lastmonth : 12 , lyear[ 0 ] );
		lmonth[ 0 ]--;
	}

	return lday[ 0 ] < 0 ? 0 : lday[ 0 ];
}

num_to_date( num, output[ ] )
{
	new date[ 3 ]; 
	date[ 0 ] = day + num;
	date[ 1 ] = month;
	date[ 2 ] = year;

	while( date[ 0 ] > get_days_in_month( date[ 1 ], date[ 2 ] ) )
	{
		date[ 0 ] -= get_days_in_month( date[ 1 ], date[ 2 ] );
		date[ 1 ]++;
	}
	
	while( date[ 1 ] > 12 )
	{
		date[ 1 ] -= 12;
		date[ 2 ]++;
	}

	formatex( output, 10, "%s%i.%s%i.%i", date[ 0 ] < 10 ? "0" : "", date[ 0 ], date[ 1 ] < 10 ? "0" : "", date[ 1 ], date[ 2 ] );
	return 1;
}

change_param( line, const param[ ], num )
{
	static str[ STRLEN ];
	ArrayGetString( amxx_users, line, str, STRLEN-1 );
	static first[ 33 ], pass[ 33 ], access[ 24 ], flags[ 6 ], gdate[ 11 ], falldate[ 18 ], model[ 33 ];
	parse( str, first, 32, pass, 32, access, 23, flags, 5, gdate, 10, falldate, 17, model, 32 );
	new bool:comment;
	if( first[ 0 ] == ';' )
	{
		replace( first, 32, ";", "" );
		comment = true;
	}
	format( str, STRLEN-1, "%s^"%s^" ^"%s^" ^"%s^" ^"%s^" ^"%s^" ^"%s^" ^"%s^"", ( comment || num == 0 ) ? ( num == 0 ? param : ";" ) : "", num == 1 ? param : first, num == 2 ? param : pass, num == 3 ? param : access, num == 4 ? param : flags, num == 5 ? param : gdate, num == 6 ? param : falldate, num == 7 ? param : model );
	ArraySetString( amxx_users, line, str );
}

regex_check_ip( const g_allArgs[ ] )
{
	static const pattern[ ] = { "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)" };
	static g_returnvalue, g_error[ 32 ], Regex:g_result;

	g_result = regex_match( g_allArgs, pattern, g_returnvalue, g_error, 63 );

	if( g_result != REGEX_MATCH_FAIL && g_result != REGEX_PATTERN_FAIL && g_result != REGEX_NO_MATCH ) 
	{
		regex_free( g_result );
		return 1;
	}

	return 0;
}