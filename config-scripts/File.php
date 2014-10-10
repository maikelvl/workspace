<?php

class File {

	static public function write($file, $data)
	{
		$handle = fopen($file, "w");
        $success = fwrite($handle, $data, strlen($data));
        fclose($handle);
        if ($success)
        {
        	Logger::log("File written: $file");
        }
        else
        {
        	throw new Exception("Error writing to file: $file", 1);
        }
	}

	static public function read($file)
	{
		$handle = fopen($file, "r");
		$contents = fread($handle, filesize($file));
		fclose($handle);
		return $contents;
	}
}