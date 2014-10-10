<?php

function dd()
{
	echo "\n";
	$d = debug_backtrace();
	echo $d[0]['line'].' - '.str_replace(__DIR__.'/', '', $d[0]['file'])."\n";
	foreach(func_get_args() as $arg)
	{
		print_r($arg);
		echo "\n";
	}
	exit;
}

function d()
{
	echo "\n";
	$d = debug_backtrace();
	echo $d[0]['line'].' - '.str_replace(__DIR__.'/', '', $d[0]['file'])."\n";
	foreach(func_get_args() as $arg)
	{
		print_r($arg);
		echo "\n";
	}
}